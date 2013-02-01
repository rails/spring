require "spring/version"

module Spring
  module Client
    class Help < Command
      def call
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
  end
end
