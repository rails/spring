require "helper"
require "tmpdir"
require "fileutils"
require "active_support/core_ext/numeric/time"
require "spring/listen_watcher"
require "spring/polling_watcher"

module WatcherTests
  LATENCY = 0.01

  attr_accessor :watcher, :dir

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry_secure @dir
  end

  def touch(file, mtime = nil)
    options = {}
    options[:mtime] = mtime if mtime
    FileUtils.touch(file, options)
  end

  def assert_stale
    sleep LATENCY * 3
    assert watcher.stale?
  end

  def assert_not_stale
    sleep LATENCY * 3
    assert !watcher.stale?
  end

  def test_is_stale_when_a_watched_file_is_updated
    file = "#{@dir}/omg"
    touch file, Time.now - 2.seconds

    watcher.add_files [file]
    watcher.start

    assert_not_stale
    touch file, Time.now
    assert_stale
  end

  def test_is_stale_when_removing_files
    file = "#{@dir}/omg"
    touch file, Time.now

    watcher.add_files [file]
    watcher.start

    assert_not_stale
    FileUtils.rm(file)
    assert_stale
  end

  def test_is_stale_when_files_are_added_to_a_watched_directory
    subdir = "#{@dir}/subdir"
    FileUtils.mkdir(subdir)

    watcher.add_directories(subdir)
    watcher.start

    assert_not_stale
    touch "#{subdir}/foo", Time.now - 1.minute
    assert_stale
  end
end

if Spring::ListenWatcher.available?
  class ListenWatcherTest < ActiveSupport::TestCase
    include WatcherTests

    def watcher
      @watcher ||= Spring::ListenWatcher.new(@dir, :latency => LATENCY)
    end

    def teardown
      super
      watcher.stop
    end
  end
end

class PollingWatcherTest < ActiveSupport::TestCase
  include WatcherTests

  def watcher
    @watcher ||= Spring::PollingWatcher.new
  end
end
