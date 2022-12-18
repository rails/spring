
# Based on https://github.com/rails/spring/blob/master/lib/spring/client/run.rb

require 'bundler'
require 'json'
require 'rbconfig'
require 'socket'

require 'expedite/env'
require 'expedite/errors'
require 'expedite/send_json'

module Expedite
  class Client
    include SendJson

    FORWARDED_SIGNALS = %w(INT QUIT USR1 USR2 INFO WINCH) & Signal.list.keys
    CONNECT_TIMEOUT   = 1
    BOOT_TIMEOUT      = 20

    attr_reader :args, :env, :variant
    attr_reader :server

    def initialize(env: nil, variant: nil)
      @env = env || Env.new
      @variant = variant

      @signal_queue  = []
      @server_booted = false
    end

    def log(message)
      env.log "[client] #{message}"
    end

    def connect
      @server = UNIXSocket.open(env.socket_path)
    end

    def call(*args)
      @args = args
      begin
        connect
      rescue Errno::ENOENT, Errno::ECONNRESET, Errno::ECONNREFUSED
        cold_run
      else
        warm_run
      end
    ensure
      server.close if server
    end

    def warm_run
      run
    rescue CommandNotFound
      raise
      require "expedite/command"

      if Expedite.command(args.first)
        # Command installed since Expedite started
        stop_server
        cold_run
      else
        raise
      end
    end

    def cold_run
      boot_server
      connect
      run
    end

    def run
      verify_server_version

      application, client = UNIXSocket.pair

      queue_signals
      connect_to_application(client)
      run_command(client, application)
    rescue Errno::ECONNRESET
      exit 1
    end

    def boot_server
      env.socket_path.unlink if env.socket_path.exist?

      pid     = Process.spawn(gem_env, env.server_command, out: File::NULL)
      timeout = Time.now + BOOT_TIMEOUT

      @server_booted = true

      until env.socket_path.exist?
        _, status = Process.waitpid2(pid, Process::WNOHANG)

        if status
          # Server did not start
          raise ArgumentError, "Server exited: #{status.exitstatus}"
        elsif Time.now > timeout
          $stderr.puts "Starting Expedite server with `#{env.server_command}` " \
                       "timed out after #{BOOT_TIMEOUT} seconds"
          exit 1
        end

        sleep 0.1
      end
    end

    def server_booted?
      @server_booted
    end

    def gem_env
      bundle = Bundler.bundle_path.to_s
      paths  = Gem.path + ENV["GEM_PATH"].to_s.split(File::PATH_SEPARATOR)

      {
        "GEM_PATH" => [bundle, *paths].uniq.join(File::PATH_SEPARATOR),
        "GEM_HOME" => bundle
      }
    end

    def stop_server
      server.close
      @server = nil
      env.stop
    end

    def verify_server_version
      server_version = server.gets.chomp
      if server_version != env.version
        $stderr.puts "There is a version mismatch between the Expedite client " \
                       "(#{env.version}) and the server (#{server_version})."

        if server_booted?
          $stderr.puts "We already tried to reboot the server, but the mismatch is still present."
          exit 1
        else
          $stderr.puts "Restarting to resolve."
          stop_server
          cold_run
        end
      end
    end

    def connect_to_application(client)
      server.send_io client

      send_json server, "args" => args, "variant" => variant

      if IO.select([server], [], [], CONNECT_TIMEOUT)
        server.gets or raise CommandNotFound
      else
        raise "Error connecting to Expedite server"
      end
    end

    def run_command(client, application)
      log "sending command"

      application.send_io STDOUT
      application.send_io STDERR
      application.send_io STDIN

      send_json application, "args" => args, "env" => ENV.to_hash

      pid = server.gets
      pid = pid.chomp if pid

      # We must not close the client socket until we are sure that the application has
      # received the FD. Otherwise the FD can end up getting closed while it's in the server
      # socket buffer on OS X. This doesn't happen on Linux.
      client.close

      if pid && !pid.empty?
        log "got pid: #{pid}"

        suspend_resume_on_tstp_cont(pid)

        forward_signals(application)
        status = application.read.to_i

        log "got exit status #{status}"

        exit status
      else
        log "got no pid"
        exit 1
      end
    ensure
      application.close
    end

    def queue_signals
      FORWARDED_SIGNALS.each do |sig|
        trap(sig) { @signal_queue << sig }
      end
    end

    def suspend_resume_on_tstp_cont(pid)
      trap("TSTP") {
        log "suspended"
        Process.kill("STOP", pid.to_i)
        Process.kill("STOP", Process.pid)
      }
      trap("CONT") {
        log "resumed"
        Process.kill("CONT", pid.to_i)
      }
    end

    def forward_signals(application)
      @signal_queue.each { |sig| kill sig, application }

      FORWARDED_SIGNALS.each do |sig|
        trap(sig) { forward_signal sig, application }
      end
    end

    def forward_signal(sig, application)
      if kill(sig, application) != 0
        # If the application process is gone, then don't block the
        # signal on this process.
        trap(sig, 'DEFAULT')
        Process.kill(sig, Process.pid)
      end
    end

    def kill(sig, application)
      application.puts(sig)
      application.gets.to_i
    end
  end
end
