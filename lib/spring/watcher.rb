require "spring/watcher/abstract"
require "spring/watcher/listen"
require "spring/watcher/polling"

module Spring
  class << self
    attr_accessor :watch_interval
    attr_writer :watcher
  end

  self.watch_interval = 0.2

  def self.watcher
    @watcher ||= watcher_class.new(Spring.application_root_path, watch_interval)
  end

  def self.watcher_class
    if Watcher::Listen.available?
      Watcher::Listen
    else
      Watcher::Polling
    end
  end

  def self.watch(*items)
    watcher.add *items
  end
end
