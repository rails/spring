require "test_helper"
require "expedite/variants"

class VariantsTest < Minitest::Test
  def test_register
    assert_raises ::NotImplementedError do
      Expedite::Variants.lookup("missing")
    end

    Expedite::Variants.register("dev/*") do |name|
      assert name != nil
    end

    ["dev/abc", "dev/bcd"].each do |name|
      v = Expedite::Variants.lookup(name)
      assert v != nil
      v.after_fork(name)
    end
    assert_raises ::NotImplementedError do
      Expedite::Variants.lookup("dev")
    end

    Expedite::Variants.reset
    assert_raises ::NotImplementedError do
      Expedite::Variants.lookup("dev/abc")
    end

    # Should be able to re-register
    Expedite::Variants.register("dev/*")
  ensure
    Expedite::Variants.reset
  end
end
