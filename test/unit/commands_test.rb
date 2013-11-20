require "helper"
require "minitest/stub_any_instance"
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

  test "rake command has configurable environments" do
    command = Spring::Commands::Rake.new
    assert_nil command.env(["foo"])
    assert_equal "test", command.env(["test"])
    assert_equal "test", command.env(["test:models"])
    assert_nil command.env(["test_foo"])
  end

  test "Spring.require_commands correctly requires commands from gems" do
    mock = MiniTest::Mock.new
    mock.expect :call, true, ["spring/commands/rspec"]
    Object.stub_any_instance :require, mock do
      Gem::Specification.stub :map, ['spring-commands-rspec'] do
        Spring.require_commands
      end
    end
    mock.verify
  end

end
