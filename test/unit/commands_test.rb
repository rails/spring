require "helper"
require "spring/commands"

class CommandsTest < ActiveSupport::TestCase

  test "test command needs a test name" do
    begin
      real_stderr = $stderr
      $stderr = StringIO.new('')

      command = Spring::Commands::Test.new
      command.call([])

      assert_equal "you need to specify what test to run: spring test TEST_NAME\n", $stderr.string
    ensure
      $stderr = real_stderr
    end
  end

end
