require "test_helper"
require "expedite/actions"

class CommandsTest < Minitest::Test
  def test_register
    assert_raises ::NotImplementedError do
      Expedite::Actions.lookup("missing")
    end

    Expedite::Actions.register("dev") do
      10
    end

    cmd = Expedite::Actions.lookup("dev")
    assert cmd != nil
    assert cmd.call == 10

    Expedite::Actions.reset
    assert_raises ::NotImplementedError do
      Expedite::Actions.lookup("dev")
    end
  end

  def test_boot
    assert Expedite::Actions.lookup("expedite/boot") != nil
  end
end
