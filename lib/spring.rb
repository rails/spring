require "rbconfig"
require "socket"
require "pty"
require "io/console"

require "spring/version"
require "spring/sid"
require "spring/env"
require "spring/commands"

class Spring
  SERVER_COMMAND = [
    File.join(*RbConfig::CONFIG.values_at('bindir', 'RUBY_INSTALL_NAME')),
    "-r", "bundler/setup",
    "-r", "spring/server",
    "-e", "Spring::Server.boot"
  ]

  def self.run(args)
    exit new.run(args)
  end

  attr_reader :env

  def initialize
    @env = Env.new
  end

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

  # Boot the server into the process group of the current session.
  # This will cause it to be automatically killed once the session
  # ends (i.e. when the user closes their terminal).
  def boot_server
    env.socket_path.unlink if env.socket_path.exist?
    Process.spawn(*SERVER_COMMAND, pgroup: SID.pgid)
    sleep 0.1 until env.socket_path.exist?
  end

  def run(args)
    boot_server unless server_running?

    application, client = UNIXSocket.pair

    server = UNIXSocket.open(env.socket_name)
    server.send_io client
    server.puts rails_env_for(args.first)

    status = server.read(1)

    server.close
    client.close

    return false unless status == "0"

    application.send_io STDOUT
    application.send_io STDERR
    application.send_io stdin_slave

    application.puts args.length

    args.each do |arg|
      application.puts  arg.length
      application.write arg
    end

    # FIXME: receive exit status from server
    application.read
    true
  rescue Errno::ECONNRESET
    false
  ensure
    application.close if application
  end

  private

  def rails_env_for(command_name)
    command = Spring.command(command_name)

    if command.respond_to?(:env)
      command.env
    else
      ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
    end
  end

  # FIXME: need to make special chars (e.g. arrow keys) work
  def stdin_slave
    master, slave = PTY.open
    master.raw!

    Thread.new {
      until STDIN.closed?
        # This makes special chars work, but has some weird side-effects that
        # I need to figure out.
        # master.write STDIN.getch

        master.write STDIN.read(1)
      end
    }

    slave
  end
end
