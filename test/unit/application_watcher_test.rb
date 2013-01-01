require "helper"
require "fileutils"
require "active_support/core_ext/numeric/time"
require "spring/application_watcher"

class ApplicationWatcherTest < Test::Unit::TestCase
  def setup
    @dir = "/tmp/spring"
    FileUtils.mkdir(@dir)
  end

  def teardown
    FileUtils.rm_r(@dir)
  end

  def touch(file, mtime = nil)
    options = {}
    options[:mtime] = mtime if mtime
    FileUtils.touch(file, options)
  end

  def test_file_mtime
    file = "#{@dir}/omg"
    touch file, Time.now - 2.seconds

    watcher = Spring::ApplicationWatcher.new
    watcher.add_files [file]

    assert !watcher.stale?
    touch file, Time.now
    assert watcher.stale?
  end

  def test_glob
    FileUtils.mkdir("#{@dir}/1")
    FileUtils.mkdir("#{@dir}/2")

    watcher = Spring::ApplicationWatcher.new
    watcher.add_globs ["#{@dir}/1/*.rb", "#{@dir}/2/*"]

    assert !watcher.stale?

    touch "#{@dir}/1/foo", Time.now - 1.minute
    assert !watcher.stale?

    touch "#{@dir}/1/foo.rb", 2.seconds
    assert watcher.stale?

    watcher.reset
    assert !watcher.stale?

    touch "#{@dir}/2/foo", Time.now
    assert watcher.stale?
  end
end
