require "rbconfig"
require "socket"
require "pty"

require "spring/client"
require "spring/version"

class Spring
  def self.run(args)
    exit new.run(args)
  end

  def run(args)
    if self.class.command_registered?(args.first)
      Client::Run.call args
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
 cucumber    Execute a Cucumber feature
EOT
    false
  end
end
