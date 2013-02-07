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

  test "prints error message when preloaded file does not exist" do
    begin
      original_stderr = $stderr
      $stderr = StringIO.new('')
      my_command_class = Class.new(Spring::Commands::Command)
      my_command_class.preloads = %w(i_do_not_exist)

      my_command_class.new.setup
      assert_match /The #<Class:0x[0-9a-f]+> command tried to preload i_do_not_exist but could not find it./, $stderr.string
    ensure
      $stderr = original_stderr
    end
  end

end
