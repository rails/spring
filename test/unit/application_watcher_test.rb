require "helper"
require "fileutils"
require "spring/application_watcher"

class ApplicationWatcherTest < Test::Unit::TestCase
  def setup
    @dir = "/tmp/spring"
    FileUtils.mkdir(@dir)
  end

  def teardown
    FileUtils.rm_r(@dir)
  end

  def touch(file)
    sleep 0.01
    File.write(file, "omg")
  end

  def test_file_mtime
    file = "#{@dir}/omg"
    touch file

    watcher = Spring::ApplicationWatcher.new
    watcher.add_files [file]

    assert !watcher.stale?

    touch file
    assert watcher.stale?
  end

  def test_glob
    FileUtils.mkdir("#{@dir}/1")
    FileUtils.mkdir("#{@dir}/2")

    watcher = Spring::ApplicationWatcher.new
    watcher.add_globs ["#{@dir}/1/*.rb", "#{@dir}/2/*"]

    assert !watcher.stale?

    touch "#{@dir}/1/foo"
    assert !watcher.stale?

    touch "#{@dir}/1/foo.rb"
    assert watcher.stale?

    watcher.reset
    assert !watcher.stale?

    touch "#{@dir}/2/foo"
    assert watcher.stale?
  end
end
