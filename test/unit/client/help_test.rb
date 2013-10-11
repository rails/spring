require 'helper'

require "spring/client/command"
require 'spring/client/help'
require 'spring/client'

class HelpTest < ActiveSupport::TestCase
  def spring_commands
    {
      'command' => Class.new {
        def self.description
          'Random Spring Command'
        end
      },
      'rails' => Class.new {
        def self.description
          "omg"
        end
      }
    }
  end

  def application_commands
    {
      'random' => Class.new {
        def description
          'Random Application Command'
        end
      }.new,
      'hidden' => Class.new {
        def description
          nil
        end
      }.new
    }
  end

  def setup
    @help = Spring::Client::Help.new('help', spring_commands, application_commands)
  end

  test "formatted_help generates expected output" do
    expected_output = <<-EOF
Version: #{Spring::VERSION}

Usage: spring COMMAND [ARGS]

Commands for spring itself:

  command  Random Spring Command

Commands for your application:

  rails    omg
  random   Random Application Command
    EOF

    assert_equal expected_output.chomp, @help.formatted_help
  end
end
