require "helper"
require "spring/test/watcher_test"
require "spring/watcher/polling"

class PollingWatcherTest < Spring::Test::WatcherTest
  def watcher_class
    Spring::Watcher::Polling
  end
end
