require_relative "../helper"
require "spring/commands"

class CommandsTest < ActiveSupport::TestCase
  test 'rails command sets rails environment from -e option' do
    command = Spring::Commands::Rails.new
    assert_equal 'test', command.env(['-e', 'test'])
    assert_equal 'test', command.env(['-e=test'])
  end

  test 'rails command sets rails environment from --environment option' do
    command = Spring::Commands::Rails.new
    assert_equal 'test', command.env(['--environment', 'test'])
    assert_equal 'test', command.env(['--environment=test'])
  end

  test 'rails command ignores first argument if it is a flag except -e and --environment' do
    command = Spring::Commands::Rails.new
    assert_nil command.env(['--sandbox'])
  end

  test 'rails command uses last environment option' do
    command = Spring::Commands::Rails.new
    assert_equal 'development', command.env(['-e', 'test', '--environment=development'])
  end

  test 'rails command ignores additional arguments' do
    command = Spring::Commands::Rails.new
    assert_equal 'test', command.env(['-e', 'test', 'puts 1+1'])
  end

  test "rake command has configurable environments" do
    command = Spring::Commands::Rake.new
    assert_nil command.env(["foo"])
    assert_equal "test", command.env(["test"])
    assert_equal "test", command.env(["test:models"])
    assert_nil command.env(["test_foo"])
  end

  test 'RailsTest#env defaults to test rails environment' do
    command = Spring::Commands::RailsTest.new
    assert_equal 'test', command.env([])
  end

  test 'RailsTest#env sets rails environment from --environment option' do
    command = Spring::Commands::RailsTest.new
    assert_equal 'development', command.env(['--environment', 'development'])
    assert_equal 'development', command.env(['--environment=development'])
  end

  test 'RailsTest#env sets rails environment from -e option' do
    command = Spring::Commands::RailsTest.new
    assert_equal 'development', command.env(['-e', 'development'])
    assert_equal 'development', command.env(['-e=development'])
  end
end
