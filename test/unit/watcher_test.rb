require "helper"
require "tmpdir"
require "fileutils"
require "timeout"
require "active_support/core_ext/numeric/time"
require "spring/watcher"
require "spring/watcher/polling"
require "spring/watcher/listen"

module WatcherTests
  LATENCY = 0.001
  TIMEOUT = 1

  attr_accessor :dir

  def watcher
    @watcher ||= watcher_class.new(dir, LATENCY)
  end

  def setup
    @dir = File.realpath(Dir.mktmpdir)
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
    timeout = Time.now + TIMEOUT
    sleep LATENCY until watcher.stale? || Time.now > timeout
    assert watcher.stale?
  end

  def assert_not_stale
    sleep LATENCY * 10
    assert !watcher.stale?
  end

  def test_starting_with_no_file
    file = "#{@dir}/omg"
    touch file, Time.now - 2.seconds

    watcher.start
    watcher.add file

    assert_not_stale
    touch file, Time.now
    assert_stale
  end

  def test_is_stale_when_a_watched_file_is_updated
    file = "#{@dir}/omg"
    touch file, Time.now - 2.seconds

    watcher.add file
    watcher.start

    assert_not_stale
    touch file, Time.now
    assert_stale
  end

  def test_is_stale_when_removing_files
    file = "#{@dir}/omg"
    touch file, Time.now

    watcher.add file
    watcher.start

    assert_not_stale
    FileUtils.rm(file)
    assert_stale
  end

  def test_is_stale_when_files_are_added_to_a_watched_directory
    subdir = "#{@dir}/subdir"
    FileUtils.mkdir(subdir)

    watcher.add subdir
    watcher.start

    assert_not_stale
    touch "#{subdir}/foo", Time.now - 1.minute
    assert_stale
  end

  def test_is_stale_when_a_file_is_changed_in_a_watched_directory
    subdir = "#{@dir}/subdir"
    FileUtils.mkdir(subdir)
    touch "#{subdir}/foo", Time.now - 1.minute

    watcher.add subdir
    watcher.start

    assert_not_stale
    touch "#{subdir}/foo", Time.now
    assert_stale
  end

  def test_adding_doesnt_wipe_stale_state
    file = "#{@dir}/omg"
    file2 = "#{@dir}/foo"
    touch file, Time.now - 2.seconds
    touch file2, Time.now - 2.seconds

    watcher.add file
    watcher.start

    assert_not_stale

    touch file, Time.now
    watcher.add file2

    assert_stale
  end

  def test_on_stale
    file = "#{@dir}/omg"
    touch file, Time.now - 2.seconds

    watcher.add file
    watcher.start

    stale = false
    watcher.on_stale { stale = true }

    touch file, Time.now

    Timeout.timeout(1) { sleep 0.01 until stale }
    assert stale

    # Check that we only get notified once
    stale = false
    sleep LATENCY * 3
    assert !stale
  end

  def test_add_relative_path
    File.write("#{dir}/foo", "foo")
    watcher.add "foo"
    assert_equal ["#{dir}/foo"], watcher.files.to_a
  end

  def test_add_dot_relative_path
    File.write("#{dir}/foo", "foo")
    watcher.add "./foo"
    assert_equal ["#{dir}/foo"], watcher.files.to_a
  end

  def test_add_non_existant_file
    watcher.add './foobar'
    assert watcher.files.empty?
  end
end

class ListenWatcherTest < ActiveSupport::TestCase
  include WatcherTests

  def watcher_class
    Spring::Watcher::Listen
  end

  test "root directories" do
    begin
      other_dir_1 = File.realpath(Dir.mktmpdir)
      other_dir_2 = File.realpath(Dir.mktmpdir)
      File.write("#{other_dir_1}/foo", "foo")
      File.write("#{dir}/foo", "foo")

      watcher.add "#{other_dir_1}/foo"
      watcher.add other_dir_2
      watcher.add "#{dir}/foo"

      assert_equal [dir, other_dir_1, other_dir_2].sort, watcher.base_directories.sort
    ensure
      FileUtils.rmdir other_dir_1
      FileUtils.rmdir other_dir_2
    end
  end
end

class PollingWatcherTest < ActiveSupport::TestCase
  include WatcherTests

  def watcher_class
    Spring::Watcher::Polling
  end
end
