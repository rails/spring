require "test_helper"
require "expedite/server/agent_manager"
require "expedite/env"

class ApplicationManagerTest < Minitest::Test
  def test_settings
    env = Expedite::Env.new(root: "#{File.dirname(__FILE__)}/fixtures")
    env.load_helper

    parent = Expedite::Server::AgentManager.new("parent", env)

    assert parent.parent == nil
    assert parent.keep_alive == false

    assert parent.pid == nil
    parent.start
    assert parent.pid != nil
  ensure
    parent&.stop
    Expedite::Agents.reset
  end
end
