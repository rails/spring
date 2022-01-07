require 'socket'

require 'expedite/env'
require 'expedite/errors'
require 'expedite/protocol'

module Expedite
  module Client
    class Invoke
      CONNECT_TIMEOUT   = 1
      BOOT_TIMEOUT      = 20

      attr_reader :args, :env, :agent
      attr_reader :server

      def initialize(env: nil, agent: nil)
        @env = env || Env.new
        @agent = agent

        @server_booted = false
      end

      def call(*args)
        begin
          connect
        rescue Errno::ENOENT, Errno::ECONNRESET, Errno::ECONNREFUSED
          boot_server
          connect
        end

        perform(*args)
      ensure
        server.close if server
      end

      def perform(*args)
        verify_server_version

        agent, client = UNIXSocket.pair
        connect_to_agent(client, args)
        run_command(client, agent, args)
      end

      def verify_server_version
        server_version = server.gets.chomp
        raise ArgumentError, "Server mismatch. Expected #{env.version}, got #{server_version}." if server_version != env.version
      end

      def connect_to_agent(client, args)
        server.send_io client

        server.send_object("args" => args, "agent" => agent)

        if IO.select([server], [], [], CONNECT_TIMEOUT)
          server.gets or raise CommandNotFound
        else
          raise "Error connecting to Expedite server"
        end
      end

      def run_command(client, agent, args)
        log "sending command"

        agent.send_io STDOUT
        agent.send_io STDERR
        agent.send_io STDIN

        agent.send_object("args" => args, "env" => ENV.to_hash)

        pid = server.gets
        pid = pid.chomp if pid

        # We must not close the client socket until we are sure that the application has
        # received the FD. Otherwise the FD can end up getting closed while it's in the server
        # socket buffer on OS X. This doesn't happen on Linux.
        client.close

        if pid && !pid.empty?
          log "got pid: #{pid}"

          ## suspend_resume_on_tstp_cont(pid)

          ## forward_signals(application)
          result = agent.recv_object
          if result.key?("exception")
            e = result["exception"]
            log "got exception #{e}"
            raise e
          end

          ret = result["return"]
          log "got return value #{ret}"
          return ret
        else
          log "got no pid"
          raise UnknownError, "got no pid"
        end
      ensure
        agent.close
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

      def stop_server
        server.close
        @server = nil
        env.stop
      end

      def log(message)
        env.log "[client] #{message}"
      end

      def connect
        @server = UNIXSocket.open(env.socket_path)
      end

      def gem_env
        bundle = Bundler.bundle_path.to_s
        paths  = Gem.path + ENV["GEM_PATH"].to_s.split(File::PATH_SEPARATOR)

        {
          "GEM_PATH" => [bundle, *paths].uniq.join(File::PATH_SEPARATOR),
          "GEM_HOME" => bundle
        }
      end
    end
  end
end
