require "rbconfig"
require "socket"

require "spring/commands"

module Spring
  module Client
    class Run < Command
      SERVER_COMMAND = [
        File.join(*RbConfig::CONFIG.values_at('bindir', 'RUBY_INSTALL_NAME')),
        "-I", File.expand_path("../../..", __FILE__),
        "-r", "spring/server",
        "-r", "bundler/setup",
        "-e", "Spring::Server.boot"
      ]

      FORWARDED_SIGNALS = %w(INT QUIT USR1 USR2 INFO)

      def call
        Spring.verify_environment!
        boot_server unless env.server_running?

        application, client = UNIXSocket.pair

        server = UNIXSocket.open(env.socket_name)

        verify_server_version(server)
        server.send_io client
        server.puts rails_env_for(*args)

        application.send_io STDOUT
        application.send_io STDERR
        application.send_io STDIN

        application.puts args.length

        args.each do |arg|
          application.puts  arg.length
          application.write arg
        end

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
      rescue Errno::ECONNRESET
        exit 1
      ensure
        application.close if application
        server.close if server
      end

      def boot_server
        env.socket_path.unlink if env.socket_path.exist?
        Process.spawn(*SERVER_COMMAND)
        sleep 0.1 until env.socket_path.exist?
      end

      def verify_server_version(server)
        server_version = server.gets.chomp
        if server_version != env.version
          $stderr.puts <<-ERROR
There is a version mismatch beween the spring client and the server.
You should restart the server and make sure to use the same version.

CLIENT: #{env.version}, SERVER: #{server_version}
ERROR
          exit 1
        end
      end

      def rails_env_for(command_name, *tail)
        command = Spring.command(command_name)

        if command.respond_to?(:env)
          env = command.env(tail)
        end

        env || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
      end

      def forward_signals(pid)
        (FORWARDED_SIGNALS & Signal.list.keys).each do |sig|
          trap(sig) { Process.kill(sig, -Process.getpgid(pid)) }
        end
      end
    end
  end
end
