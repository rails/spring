require "helper"
require "spring/commands"

class CommandsTest < Test::Unit::TestCase

  def test_test_command_needs_a_test_name
    real_stderr = $stderr
    $stderr = StringIO.new('')

    command = Spring::Commands::Test.new
    command.call([])

    assert_equal "you need to specify what test to run: spring test TEST_NAME\n", $stderr.string
  ensure
    $stderr = real_stderr
  end
end
