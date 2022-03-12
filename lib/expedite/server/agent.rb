# Based on https://github.com/rails/spring/blob/master/lib/spring/application.rb
require 'json'
require 'pty'
require 'set'
require 'socket'
require 'expedite/actions'
require 'expedite/env'
require 'expedite/failsafe_thread'
require 'expedite/protocol'
require 'expedite/signals'
require 'expedite/agents'

module Expedite
  def self.agent
    app.agent
  end

  def self.app=(app)
    @app = app
  end
  def self.app
    @app
  end

  module Server
    # This code runs in the process that has the actual code pre-loaded, and is
    # used to serve requests.
    # * An "invoke" request is handled in the agent itself.
    # * A "fork" request causes the agent to fork, and the forked process handles
    #   the request.
    # Each agent processes a single request at a time, unless it is an
    # Expedite::Action::Boot request which is used to make derived agents.
    class Agent
      include Signals

      attr_reader :agent
      attr_reader :manager, :env

      def initialize(agent:, manager:, env:)
        @agent      = agent
        @manager      = manager
        @env          = env
        @mutex        = Mutex.new
        @waiting      = Set.new
        @preloaded    = false
        @state        = :initialized
        @interrupt    = IO.pipe
      end

      def boot
        # This is necessary for the terminal to work correctly when we reopen stdin.
        Process.setsid rescue Errno::EPERM

        Expedite.app = self

        Signal.trap("TERM") { terminate }

        env.load_helper
        eager_preload if false #if ENV.delete("SPRING_PRELOAD") == "1"
        run
      end

      def state(val)
        return if exiting?
        log "#{@state} -> #{val}"
        @state = val
      end

      def state!(val)
        state val
        @interrupt.last.write "."
      end

      def app_name
        env.app_name
      end

      def log(message)
        env.log "[application:#{agent}] #{message}"
      end

      def preloaded?
        @preloaded
      end

      def preload_failed?
        @preloaded == :failure
      end

      def exiting?
        @state == :exiting
      end

      def terminating?
        @state == :terminating
      end

      def initialized?
        @state == :initialized
      end

      def preload
        log "preloading app"

        @preloaded = :success
      rescue Exception => e
        @preloaded = :failure
        raise e unless initialized?
      end

      def eager_preload
        with_pty { preload }
      end

      def run
        $0 = "expedite agent | #{app_name} | #{agent}"

        Expedite::Agents.lookup(agent).after_fork(agent)

        state :running
        manager.puts

        loop do
          IO.select [manager, @interrupt.first]

          if terminating? || preload_failed?
            exit
          else
            serve manager.recv_io(UNIXSocket)
          end
        end
      end

      def serve(client)
        puts "got client"
        manager.puts

        _stdout, stderr, _stdin = streams = 3.times.map { client.recv_io }
        [STDOUT, STDERR, STDIN].zip(streams).each { |a, b| a.reopen(b) }

        preload unless preloaded?

        args, env, method = client.recv_object.values_at("args", "env", "method")

        exec_name = args.shift
        action    = Expedite::Actions.lookup(exec_name)
        action.setup(client)

        connect_database # why are we connecting prior? is this for invoke?
        pid = case method
        when "invoke"
          serve_invoke(client, action, args, env)
        else
          serve_fork(client, action, args, env)
        end

        disconnect_database

        log "forked #{pid}" # pid is current process
        manager.puts pid

        # Boot makes a new application, so we don't wait for it
        if action.is_a?(Expedite::Action::Boot)
          Process.detach(pid)
        else
          wait pid, streams, client
        end
      rescue Exception => e
        log "exception: #{e} at #{e.backtrace.join("\n")}"
        manager.puts unless pid

        if streams && !e.is_a?(SystemExit)
          print_exception(stderr, e)
          streams.each(&:close)
        end

        client.puts(1) if pid
        client.close
      ensure
        # Redirect STDOUT and STDERR to prevent from keeping the original FDs
        # (i.e. to prevent `spring rake -T | grep db` from hanging forever),
        # even when exception is raised before forking (i.e. preloading).
        reset_streams
      end

      # Returns pid of the current process
      def serve_invoke(client, action, args, env)
        begin
          ret = action.call(*args)
        rescue Exception => e
          client.send_object({"exception" => e}, self.env)
        else
          client.send_object({"return" => ret}, self.env)
        end
        Process.pid
      end

      def serve_fork(client, action, args, env)
        fork do
          Process.setsid
          IGNORE_SIGNALS.each { |sig| trap(sig, "DEFAULT") }
          trap("TERM", "DEFAULT")

          # Load in the current env vars, except those which *were* changed when Spring started
          env.each { |k, v| ENV[k] = v }

          # requiring is faster, so if config.cache_classes was true in
          # the environment's config file, then we can respect that from
          # here on as we no longer need constant reloading.
          if @original_cache_classes
            ActiveSupport::Dependencies.mechanism = :require
            Rails.application.config.cache_classes = true
          end

          connect_database
          srand

          invoke_after_fork_callbacks
          shush_backtraces

          begin
            ret = action.call(*args)
          rescue => e
            client.send_object({"exception" => e}, self.env)
          else
            client.send_object({"return" => ret}, self.env)
          end
        end
      end

      def terminate
        if exiting?
          # Ensure that we do not ignore subsequent termination attempts
          log "forced exit"
          @waiting.each { |pid| Process.kill("TERM", pid) }
          Kernel.exit
        else
          state! :terminating
        end
      end

      def exit
        state :exiting
        manager.shutdown(:RDWR)
        exit_if_finished
        sleep
      end

      def exit_if_finished
        @mutex.synchronize {
          Kernel.exit if exiting? && @waiting.empty?
        }
      end

      def invoke_after_fork_callbacks
        # TODO:
      end

      def disconnect_database
        ActiveRecord::Base.remove_connection if active_record_configured?
      end

      def connect_database
        ActiveRecord::Base.establish_connection if active_record_configured?
      end

      # This feels very naughty
      def shush_backtraces
        Kernel.module_eval do
          old_raise = Kernel.method(:raise)
          remove_method :raise
          define_method :raise do |*args|
            begin
              old_raise.call(*args)
            ensure
              if $!
                lib = File.expand_path("..", __FILE__)
                $!.backtrace.reject! { |line| line.start_with?(lib) }
              end
            end
          end
          private :raise
        end
      end

      def print_exception(stream, error)
        first, rest = error.backtrace.first, error.backtrace.drop(1)
        stream.puts("#{first}: #{error} (#{error.class})")
        rest.each { |line| stream.puts("\tfrom #{line}") }
      end

      def with_pty
        PTY.open do |master, slave|
          [STDOUT, STDERR, STDIN].each { |s| s.reopen slave }
          reader_thread = Expedite.failsafe_thread { master.read }
          begin
            yield
          ensure
            reader_thread.kill
            reset_streams
          end
        end
      end

      def reset_streams
        [STDOUT, STDERR].each do |stream|
          stream.reopen(env.log_file)
        end
        STDIN.reopen("/dev/null")
      end

      def wait(pid, streams, client)
        if pid != Process.pid
          @mutex.synchronize { @waiting << pid }
        end

        # Wait in a separate thread so we can run multiple actions at once
        Expedite.failsafe_thread {
          begin
            exitstatue = if pid == Process.pid
              log "#{pid} is current process"
              0
            else
              _, status = Process.wait2 pid
              log "#{pid} exited with #{status.exitstatus}"
            end

            streams.each(&:close)
            client.puts(exitstatus)
            client.close
          ensure
            if pid != Process.pid
              @mutex.synchronize { @waiting.delete pid }
            end
            exit_if_finished
          end
        }

        Expedite.failsafe_thread {
          while signal = client.gets.chomp
            begin
              Process.kill(signal, -Process.getpgid(pid))
              client.puts(0)
            rescue Errno::ESRCH
              client.puts(1)
            end
          end
        }
      end

      private

      def active_record_configured?
        defined?(ActiveRecord::Base) && ActiveRecord::Base.configurations.any?
      end
    end
  end
end
