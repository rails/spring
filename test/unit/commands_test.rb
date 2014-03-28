require "helper"
require "spring/commands"

class CommandsTest < ActiveSupport::TestCase
  test 'console command sets rails environment from command-line option' do
    command = Spring::Commands::RailsConsole.new
    assert_equal 'test', command.env(['test'])
  end

  test 'console command ignores first argument if it is a flag' do
    command = Spring::Commands::RailsConsole.new
    assert_nil command.env(['--sandbox'])
  end

  test 'Runner#env sets rails environment from command-line option' do
    command = Spring::Commands::RailsRunner.new
    assert_equal 'test', command.env(['-e', 'test', 'puts 1+1'])
  end

  test 'RailsRunner#env sets rails environment from long form of command-line option' do
    command = Spring::Commands::RailsRunner.new
    assert_equal 'test', command.env(['--environment=test', 'puts 1+1'])
  end

  test 'RailsRunner#env ignores insignificant arguments' do
    command = Spring::Commands::RailsRunner.new
    assert_nil command.env(['puts 1+1'])
  end

  test 'RailsRunner#extract_environment removes -e <env>' do
    command = Spring::Commands::RailsRunner.new
    args = ['-b', '-a', '-e', 'test', '-r']
    assert_equal [['-b', '-a', '-r'], 'test'], command.extract_environment(args)
  end

  test 'RailsRunner#extract_environment removes --environment=<env>' do
    command = Spring::Commands::RailsRunner.new
    args = ['-b', '--environment=test', '-a', '-r']
    assert_equal [['-b', '-a', '-r'], 'test'], command.extract_environment(args)
  end

  test "rake command has configurable environments" do
    command = Spring::Commands::Rake.new
    assert_nil command.env(["foo"])
    assert_equal "test", command.env(["test"])
    assert_equal "test", command.env(["test:models"])
    assert_nil command.env(["test_foo"])
  end
end
