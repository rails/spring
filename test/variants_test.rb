require "test_helper"
require "expedite/agents"

class AgentsTest < Minitest::Test
  def test_register
    assert_raises ::NotImplementedError do
      Expedite::Agents.lookup("missing")
    end

    Expedite::Agents.register("dev/*") do |name|
      assert name != nil
    end

    ["dev/abc", "dev/bcd"].each do |name|
      v = Expedite::Agents.lookup(name)
      assert v != nil
      v.after_fork(name)
    end
    assert_raises ::NotImplementedError do
      Expedite::Agents.lookup("dev")
    end

    Expedite::Agents.reset
    assert_raises ::NotImplementedError do
      Expedite::Agents.lookup("dev/abc")
    end

    # Should be able to re-register
    Expedite::Agents.register("dev/*")
  ensure
    Expedite::Agents.reset
  end
end
