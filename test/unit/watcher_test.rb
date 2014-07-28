require "helper"
require "spring/test/watcher_test"
require "spring/watcher/polling"
require "spring/watcher/listen"

class ListenWatcherTest < Spring::Test::WatcherTest
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

  test "root directories with a root subpath directory" do
    begin
      other_dir_1 = "#{dir}_other"
      other_dir_2 = "#{dir}_core"
      # same subpath as dir but with _other or _core appended
      FileUtils::mkdir_p(other_dir_1)
      FileUtils::mkdir_p(other_dir_2)
      File.write("#{other_dir_1}/foo", "foo")
      File.write("#{other_dir_2}/foo", "foo")
      File.write("#{dir}/foo", "foo")

      watcher.add "#{other_dir_1}/foo"
      watcher.add other_dir_2

      assert_equal [dir, other_dir_1, other_dir_2].sort, watcher.base_directories.sort
    ensure
      FileUtils.rmdir other_dir_1
      FileUtils.rmdir other_dir_2
    end
  end
end

class PollingWatcherTest < Spring::Test::WatcherTest
  def watcher_class
    Spring::Watcher::Polling
  end
end
