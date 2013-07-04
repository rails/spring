require "rbconfig"
require "socket"

module Spring
  module Client
    class Run < Command
      FORWARDED_SIGNALS = %w(INT QUIT USR1 USR2 INFO) & Signal.list.keys

      def server
        @server ||= UNIXSocket.open(env.socket_name)
      end

      def call
        boot_server unless env.server_running?
        verify_server_version

        application, client = UNIXSocket.pair

        connect_to_application(client)
        run_command(client, application)
      rescue Errno::ECONNRESET
        exit 1
      ensure
        server.close if @server
      end

      def boot_server
        env.socket_path.unlink if env.socket_path.exist?
        fork {
          require "spring/server"
          Spring::Server.boot
        }
        sleep 0.1 until env.socket_path.exist?
      end

      def verify_server_version
        server_version = server.gets.chomp
        if server_version != env.version
          $stderr.puts <<-ERROR
There is a version mismatch between the spring client and the server.
You should restart the server and make sure to use the same version.

CLIENT: #{env.version}, SERVER: #{server_version}
ERROR
          exit 1
        end
      end

      def connect_to_application(client)
        server.send_io client
        send_json server, "args" => args, "default_rails_env" => default_rails_env
        server.gets or raise CommandNotFound
      end

      def run_command(client, application)
        application.send_io STDOUT
        application.send_io STDERR
        application.send_io STDIN

        send_json application, args

        pid = server.gets
        pid = pid.chomp if pid

        # We must not close the client socket until we are sure that the application has
        # received the FD. Otherwise the FD can end up getting closed while it's in the server
        # socket buffer on OS X. This doesn't happen on Linux.
        client.close

        if pid && !pid.empty?
          forward_signals(pid.to_i)
          exit application.read.to_i
        else
          exit 1
        end
      ensure
        application.close
      end

      def forward_signals(pid)
        FORWARDED_SIGNALS.each do |sig|
          trap(sig) { forward_signal sig, pid }
        end
      end

      def forward_signal(sig, pid)
        Process.kill(sig, -Process.getpgid(pid))
      rescue Errno::ESRCH
        # If the application process is gone, then don't block the
        # signal on this process.
        trap(sig, 'DEFAULT')
        Process.kill(sig, Process.pid)
      end

      def send_json(socket, data)
        data = JSON.dump(data)

        socket.puts  data.bytesize
        socket.write data
      end

      def default_rails_env
        ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
      end
    end
  end
end
