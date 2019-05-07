require_relative "../helper"
require_relative "../support/watcher_test"
require "spring/watcher/polling"

class PollingWatcherTest < Spring::Test::WatcherTest
  def watcher_class
    Spring::Watcher::Polling
  end

  test "skips staleness checks if already stale" do
    class << watcher
      attr_reader :checked_when_stale_count
      attr_reader :checked_when_not_stale_count

      def check_stale
        @checked_when_stale_count = 0 unless defined? @checked_when_stale_count
        @checked_when_not_stale_count = 0 unless defined? @checked_when_not_stale_count

        if stale?
          @checked_when_stale_count += 1
        else
          @checked_when_not_stale_count += 1
        end

        super
      end

      # Wait for the poller thread to finish.
      def join
        @poller.join if @poller
      end
    end

    # Track when we're marked as stale.
    on_stale_count = 0
    watcher.on_stale { on_stale_count += 1 }

    # Add a file to watch and start polling.
    file = "#{@dir}/omg"
    touch file, Time.now - 2.seconds
    watcher.add file
    watcher.start
    assert watcher.running?

    # First touch bumps mtime and marks as stale.
    touch file, Time.now - 1.second
    Timeout.timeout(1) { watcher.join }
    assert !watcher.running?
    assert_equal 0, watcher.checked_when_stale_count
    assert_equal 1, watcher.checked_when_not_stale_count
    assert_equal 1, on_stale_count

    # Second touch skips mtime check because it's already stale.
    touch file, Time.now
    sleep 1
    assert_equal 0, watcher.checked_when_stale_count
    assert_equal 1, watcher.checked_when_not_stale_count
    assert_equal 1, on_stale_count
  end
end
