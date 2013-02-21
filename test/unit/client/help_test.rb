require 'helper'

require "spring/client/command"
require 'spring/client/help'
require 'spring/client'

class RandomSpringCommand
  def self.description
    'Random Spring Command'
  end
end

class RandomApplicationCommand
  def description
    'Random Application Command'
  end
end

class HelpTest < ActiveSupport::TestCase
  def spring_commands
    { 'command' => RandomSpringCommand }
  end

  def application_commands
    @application_commands ||= begin
                                command = RandomApplicationCommand.new
                                { 'random' => command, 'r' => command }
                              end
  end

  def setup
    @help = Spring::Client::Help.new('help', spring_commands, application_commands)
  end

  test "formatted_help generates expected output" do
    expected_output = <<-EOF
Usage: spring COMMAND [ARGS]

Commands for spring itself:

  command    Random Spring Command

Commands for your application:

  random, r  Random Application Command
    EOF

    assert_equal expected_output.chomp, @help.formatted_help
  end
end
