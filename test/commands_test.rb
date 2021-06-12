require "test_helper"
require "expedite/commands"

class CommandsTest < Minitest::Test
  def test_register
    assert_raises ::NotImplementedError do
      Expedite::Commands.lookup("missing")
    end

    Expedite::Commands.register("dev") do
      10
    end

    cmd = Expedite::Commands.lookup("dev")
    assert cmd != nil
    assert cmd.call == 10

    Expedite::Commands.reset
    assert_raises ::NotImplementedError do
      Expedite::Commands.lookup("dev")
    end
  end

  def test_boot
    assert Expedite::Commands.lookup("expedite/boot") != nil
  end
end
