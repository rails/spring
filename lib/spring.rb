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
    File.expand_path("../spring/server.rb", __FILE__)
  ]

  def self.run(args)
    exit new.run(args)
  end

  attr_reader :env

  def initialize
    @env = Env.new
  end

  def server_running?
    env.socket_path.exist?
  end

  def boot_server
    # Boot the server into the process group of the current session.
    # This will cause it to be automatically killed once the session
    # ends (i.e. when the user closes their terminal).
    Process.spawn(*SERVER_COMMAND, pgroup: SID.pgid)
    sleep 0.1 until server_running?
  end

  def run(args)
    boot_server unless server_running?

    socket = UNIXSocket.open(env.socket_name)
    socket.write rails_env_for(args.first)
    socket.close

    socket = UNIXSocket.open(env.socket_name)

    socket.send_io STDOUT
    socket.send_io STDERR
    socket.send_io stdin_slave

    socket.puts args.length

    args.each do |arg|
      socket.puts  arg.length
      socket.write arg
    end

    # FIXME: receive exit status from server
    socket.read
    true
  rescue Errno::ECONNRESET
    false
  ensure
    socket.close if socket
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
