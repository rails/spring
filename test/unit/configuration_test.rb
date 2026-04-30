require_relative "../helper"
require "spring/configuration"

class ConfigurationTest < ActiveSupport::TestCase
  test "after_environment_load_callbacks is empty by default" do
    assert_equal [], Spring.after_environment_load_callbacks
  end

  test "after_environment_load registers a callback" do
    callbacks = []
    Spring.stub(:after_environment_load_callbacks, callbacks) do
      Spring.after_environment_load { true }
    end
    assert_equal 1, callbacks.size
  end

  test "after_environment_load accumulates multiple callbacks in order" do
    callbacks = []
    Spring.stub(:after_environment_load_callbacks, callbacks) do
      Spring.after_environment_load { :first }
      Spring.after_environment_load { :second }
    end
    assert_equal [:first, :second], callbacks.map(&:call)
  end

  test "after_environment_load callbacks are independent from after_fork callbacks" do
    env_callbacks  = []
    fork_callbacks = []
    Spring.stub(:after_environment_load_callbacks, env_callbacks) do
      Spring.stub(:after_fork_callbacks, fork_callbacks) do
        Spring.after_environment_load { true }
      end
    end
    assert_equal 1, env_callbacks.size
    assert_equal 0, fork_callbacks.size
  end

  test "after_fork_callbacks is empty by default" do
    assert_equal [], Spring.after_fork_callbacks
  end

  test "after_fork registers a callback" do
    callbacks = []
    Spring.stub(:after_fork_callbacks, callbacks) do
      Spring.after_fork { true }
    end
    assert_equal 1, callbacks.size
  end

  test "after_fork accumulates multiple callbacks in order" do
    callbacks = []
    Spring.stub(:after_fork_callbacks, callbacks) do
      Spring.after_fork { :first }
      Spring.after_fork { :second }
    end
    assert_equal [:first, :second], callbacks.map(&:call)
  end
end
