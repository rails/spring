require "socket"

require "spring/env"
require "spring/application_manager"

module Spring
  class Server
    def self.boot
      new.boot
    end

    attr_reader :env

    def initialize(env = Env.new)
      @env          = env
      @applications = Hash.new { |h, k| h[k] = ApplicationManager.new(k) }
      @pidfile      = env.pidfile_path.open('a')
    end

    def boot
      # Ignore SIGINT and SIGQUIT otherwise the user typing ^C or ^\ on the command line
      # will kill the server/application.
      IGNORE_SIGNALS.each { |sig| trap(sig,  "IGNORE") }

      set_exit_hook
      write_pidfile
      redirect_output

      $0 = "spring server | #{env.app_name} | started #{Time.now}"

      server = UNIXServer.open(env.socket_name)
      loop { serve server.accept }
    end

    def serve(client)
      client.puts env.version
      app_client = client.recv_io
      rails_env  = client.gets.chomp

      client.puts @applications[rails_env].run(app_client)
    rescue SocketError => e
      raise e unless client.eof?
    end

    def set_exit_hook
      server_pid = Process.pid

      at_exit do
        # We don't want this hook to run in any forks of the current process
        if Process.pid == server_pid
          [env.socket_path, env.pidfile_path].each do |path|
            path.unlink if path.exist?
          end

          @applications.values.each(&:stop)
        end
      end
    end

    def write_pidfile
      if @pidfile.flock(File::LOCK_EX | File::LOCK_NB)
        @pidfile.truncate(0)
        @pidfile.write("#{Process.pid}\n")
        @pidfile.fsync
      else
        STDERR.puts "#{@pidfile.path} is locked; it looks like a server is already running"
        exit 1
      end
    end

    # We can't leave STDOUT, STDERR as they as because then they will
    # never get closed for the lifetime of the server. This means that
    # piping, e.g. "spring rake -T | grep db" won't work correctly
    # because grep will hang while waiting for its stdin to reach EOF.
    #
    # However we do want server output to go to the terminal in case
    # there are exceptions etc, so we just open the current terminal
    # device directly.
    def redirect_output
      tty = open(`tty`.chomp, "a") # ruby doesn't expose ttyname()
      STDOUT.reopen(tty)
      STDERR.reopen(tty)
    end
  end
end
