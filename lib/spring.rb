require "rbconfig"
require "socket"
require "pty"

require "spring/version"
require "spring/sid"
require "spring/env"
require "spring/commands"

class Spring
  SERVER_COMMAND = [
    File.join(*RbConfig::CONFIG.values_at('bindir', 'RUBY_INSTALL_NAME')),
    "-I", File.expand_path("../", __FILE__),
    "-r", "spring/server",
    "-r", "bundler/setup",
    "-e", "Spring::Server.boot"
  ]

  FORWARDED_SIGNALS = %w(INT QUIT USR1 USR2 INFO)

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
    if self.class.command_registered?(args.first)
      run_command(args)
    else
      print_help
    end
  end

  private

  def print_help
    puts <<-EOT
Usage: spring COMMAND [ARGS]

The most common spring commands are:
 rake        Run a rake task
 console     Start the Rails console
 runner      Execute a command with the Rails runner
 generate    Trigger a Rails generator

 test        Execute a Test::Unit test
 rspec       Execute an RSpec spec
EOT
    false
  end

  def run_command(args)
    boot_server unless server_running?

    application, client = UNIXSocket.pair

    server = UNIXSocket.open(env.socket_name)
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
      false
    else
      forward_signals(pid.to_i)
      application.read # FIXME: receive exit status from server
      true
    end
  rescue Errno::ECONNRESET
    false
  ensure
    application.close if application
    server.close if server
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
      trap(sig) { Process.kill(sig, pid) }
    end
  end
end
