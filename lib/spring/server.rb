require "socket"

require "spring/env"
require "spring/application_manager"
require "spring/process_title_updater"

# readline must be required before we setpgid, otherwise the require may hang,
# if readline has been built against libedit. See issue #70.
require "readline"

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
      # Boot the server into the process group of the current session.
      # This will cause it to be automatically killed once the session
      # ends (i.e. when the user closes their terminal).
      Process.setpgid(0, SID.pgid)

      # Ignore SIGINT and SIGQUIT otherwise the user typing ^C or ^\ on the command line
      # will kill the server/application.
      IGNORE_SIGNALS.each { |sig| trap(sig,  "IGNORE") }

      set_exit_hook
      write_pidfile
      redirect_output
      set_process_title

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
        $stderr.puts "#{@pidfile.path} is locked; it looks like a server is already running"
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
      # ruby doesn't expose ttyname()
      file = open(STDIN.tty? ? `tty`.chomp : "/dev/null", "a")
      STDOUT.reopen(file)
      STDERR.reopen(file)
    end

    def set_process_title
      ProcessTitleUpdater.run { |distance|
        "spring server | #{env.app_name} | started #{distance} ago"
      }
    end
  end
end
