require "helper"
require "spring/process_title_updater"
require "active_support/time"

class ProcessTitleUpdaterTest < ActiveSupport::TestCase
  setup do
    @start   = Time.local(2012, 2, 12, 4, 3, 12)
    @updater = Spring::ProcessTitleUpdater.new(@start) { }
  end

  test "seconds" do
    assert_equal "1 sec",  @updater.distance_in_words(@start + 1.second)
    assert_equal "2 secs", @updater.distance_in_words(@start + 2.seconds)
  end

  test "minutes" do
    assert_equal "1 min",  @updater.distance_in_words(@start + 1.minute + 10.seconds)
    assert_equal "5 mins", @updater.distance_in_words(@start + 5.minutes + 10.seconds)
  end

  test "hours" do
    assert_equal "6 hours",  @updater.distance_in_words(@start + 6.hours + 50.minutes)
  end
end
