require "helper"
require "tmpdir"
require "fileutils"
require "active_support/core_ext/numeric/time"
require "spring/watcher"

module WatcherTests
  LATENCY = 0.01

  attr_accessor :dir

  def watcher
    @watcher ||= watcher_class.new(dir, LATENCY)
  end

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry_secure @dir
    watcher.stop
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

  def test_can_io_select
    file = "#{@dir}/omg"
    touch file, Time.now - 2.seconds

    watcher.add_files [file]
    watcher.start

    Thread.new {
      sleep LATENCY * 3
      touch file, Time.now
    }

    assert IO.select([watcher], [], [], 1), "IO.select timed out before watcher was readable"
    assert watcher.stale?
  end
end

class ListenWatcherTest < ActiveSupport::TestCase
  include WatcherTests

  def watcher_class
    Spring::Watcher::Listen
  end
end

class PollingWatcherTest < ActiveSupport::TestCase
  include WatcherTests

  def watcher_class
    Spring::Watcher::Polling
  end
end
