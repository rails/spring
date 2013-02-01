require "rbconfig"
require "socket"
require "pty"

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

      def server_running?
        if env.pidfile_path.exist?
          pidfile = env.pidfile_path.open('r')
          !pidfile.flock(File::LOCK_EX | File::LOCK_NB)
        else
          false
        end
      ensure
        if pidfile
          pidfile.flock(File::LOCK_UN)
          pidfile.close
        end
      end

      def call
        boot_server unless server_running?

        application, client = UNIXSocket.pair

        server = UNIXSocket.open(env.socket_name)

        verify_server_version(server)
        server.send_io client
        server.puts rails_env_for(args.first)

        application.send_io STDOUT
        application.send_io STDERR
        application.send_io stdin_slave

        application.puts args.length

        args.each do |arg|
          application.puts  arg.length
          application.write arg
        end

        pid = server.gets.chomp

        # We must not close the client socket until we are sure that the application has
        # received the FD. Otherwise the FD can end up getting closed while it's in the server
        # socket buffer on OS X. This doesn't happen on Linux.
        client.close

        if pid.empty?
          exit 1
        else
          forward_signals(pid.to_i)
          application.read # FIXME: receive exit status from server
        end
      rescue Errno::ECONNRESET
        exit 1
      ensure
        application.close if application
        server.close if server
      end

      # Boot the server into the process group of the current session.
      # This will cause it to be automatically killed once the session
      # ends (i.e. when the user closes their terminal).
      def boot_server
        env.socket_path.unlink if env.socket_path.exist?
        Process.spawn(*SERVER_COMMAND, pgroup: SID.pgid)
        sleep 0.1 until env.socket_path.exist?
      end

      def verify_server_version(server)
        server_version = server.gets.chomp
        if server_version != env.version
          STDERR.puts <<-ERROR
There is a version mismatch beween the spring client and the server.
You should restart the server and make sure to use the same version.

CLIENT: #{env.version}, SERVER: #{server_version}
ERROR
          exit(1)
        end
      end

      def rails_env_for(command_name)
        command = Spring.command(command_name)

        if command.respond_to?(:env)
          command.env
        else
          ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
        end
      end

      def stdin_slave
        master, slave = PTY.open

        # Sadly I cannot find a way to achieve this without shelling out to stty, or
        # using a C extension library. [Ruby does not have direct support for calling
        # tcsetattr().] We don't want to use a C extension library so
        # that spring can be used by Rails in the future.
        system "stty -icanon -echo"
        at_exit { system "stty sane" }

        Thread.new { master.write STDIN.read(1) until STDIN.closed? }

        slave
      end

      def forward_signals(pid)
        (FORWARDED_SIGNALS & Signal.list.keys).each do |sig|
          trap(sig) { Process.kill(sig, -Process.getpgid(pid)) }
        end
      end
    end
  end
end
