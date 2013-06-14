require "spring/watcher/abstract"
require "spring/watcher/listen"
require "spring/watcher/polling"

module Spring
  class << self
    attr_accessor :watch_interval, :watch_via
    attr_writer :watcher
  end

  self.watch_interval = 0.2
  self.watch_via = :polling

  def self.watcher
    @watcher ||= watcher_class.new(Spring.application_root_path, watch_interval)
  end

  def self.watcher_class
    if watch_via.to_s == 'listen'
      if Watcher::Listen.available?
        Watcher::Listen
      else
        puts %Q{Listen gem was not found, please add this to your Gemfile. `gem 'listen', group: ['test','development']`
Falling back to Wather::Polling}
        Watcher::Polling
      end
    elsif watch_via.to_s == 'polling'
      Watcher::Polling
    elsif watch_via.kind_of?(Class)
      watch_via
    else
      raise NotImplementedError
    end
  end

  def self.watch(*items)
    watcher.add *items
  end
end
