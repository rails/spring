require "set"
require "spring/watcher"
require "thread"

module Spring
  class Application
    attr_reader :manager, :watcher, :spring_env

    def initialize(manager, watcher = Spring.watcher)
      @manager    = manager
      @watcher    = watcher
      @setup      = Set.new
      @spring_env = Env.new
      @preloaded  = false
      @mutex      = Mutex.new
      @waiting    = 0
      @exiting    = false

      # Workaround for GC bug in Ruby 2 which causes segfaults if watcher.to_io
      # instances get dereffed.
      @fds = [manager, watcher.to_io]
    end

    def log(message)
      spring_env.log "[application:#{ENV['RAILS_ENV']}] #{message}"
    end

    def preloaded?
      @preloaded
    end

    def exiting?
      @exiting
    end

    def preload
      log "preloading app"

      require Spring.application_root_path.join("config", "application")

      # config/environments/test.rb will have config.cache_classes = true. However
      # we want it to be false so that we can reload files. This is a hack to
      # override the effect of config.cache_classes = true. We can then actually
      # set config.cache_classes = false after loading the environment.
      Rails::Application.initializer :initialize_dependency_mechanism, group: :all do
        ActiveSupport::Dependencies.mechanism = :load
      end

      require Spring.application_root_path.join("config", "environment")

      Rails.application.config.cache_classes = false
      disconnect_database

      watcher.add loaded_application_features
      watcher.add Spring.gemfile, "#{Spring.gemfile}.lock"
      watcher.add Rails.application.paths["config/initializers"]

      @preloaded = true
    end

    def run
      log "running"
      watcher.start

      loop do
        IO.select(@fds)

        if watcher.stale?
          log "watcher stale; exiting"
          manager.close
          @exiting = true
          try_exit
          sleep
        else
          serve manager.recv_io(UNIXSocket)
        end
      end
    end

    def try_exit
      @mutex.synchronize {
        exit if exiting? && @waiting == 0
      }
    end

    def serve(client)
      log "got client"
      manager.puts

      streams = 3.times.map { client.recv_io }
      [STDOUT, STDERR].zip(streams).each { |a, b| a.reopen(b) }

      preload unless preloaded?

      args, env = JSON.load(client.read(client.gets.to_i)).values_at("args", "env")
      command   = Spring.command(args.shift)

      connect_database
      setup command

      if Rails.application.reloaders.any?(&:updated?)
        ActionDispatch::Reloader.cleanup!
        ActionDispatch::Reloader.prepare!
      end

      pid = fork {
        Process.setsid
        STDIN.reopen(streams.last)
        IGNORE_SIGNALS.each { |sig| trap(sig, "DEFAULT") }

        ARGV.replace(args)

        # Delete all env vars which are unchanged from before spring started
        Spring.original_env.each { |k, v| ENV.delete k if ENV[k] == v }

        # Load in the current env vars, except those which *were* changed when spring started
        env.each { |k, v| ENV[k] ||= v }

        connect_database
        srand

        invoke_after_fork_callbacks
        shush_backtraces

        if command.respond_to?(:call)
          command.call
        else
          exec_name = command.exec_name
          gem_name  = command.gem_name if command.respond_to?(:gem_name)

          exec = Gem.bin_path(gem_name || exec_name, exec_name)
          $0 = exec
          load exec
        end
      }

      disconnect_database
      [STDOUT, STDERR].each { |stream| stream.reopen(spring_env.log_file) }

      log "forked #{pid}"
      manager.puts pid

      # Wait in a separate thread so we can run multiple commands at once
      Thread.new {
        @mutex.synchronize { @waiting += 1 }

        _, status = Process.wait2 pid
        log "#{pid} exited with #{status.exitstatus}"

        streams.each(&:close)
        client.puts(status.exitstatus)
        client.close

        @mutex.synchronize { @waiting -= 1 }
        try_exit
      }

    rescue => e
      log "exception: #{e}"
      streams.each(&:close) if streams
      client.puts(1)
      client.close
      raise
    end

    # The command might need to require some files in the
    # main process so that they are cached. For example a test command wants to
    # load the helper file once and have it cached.
    def setup(command)
      return if @setup.include?(command.class)
      @setup << command.class

      if command.respond_to?(:setup)
        command.setup
        watcher.add loaded_application_features # loaded features may have changed
      end
    end

    def invoke_after_fork_callbacks
      Spring.after_fork_callbacks.each do |callback|
        callback.call
      end
    end

    def loaded_application_features
      $LOADED_FEATURES.select { |f| f.start_with?(File.realpath(Rails.root)) }
    end

    def disconnect_database
      ActiveRecord::Base.remove_connection if defined?(ActiveRecord::Base)
    end

    def connect_database
      ActiveRecord::Base.establish_connection if defined?(ActiveRecord::Base)
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
      end
    end
  end
end
