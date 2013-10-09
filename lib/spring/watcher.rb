require "spring/watcher/abstract"
require "spring/configuration"

module Spring
  class << self
    attr_accessor :watch_interval
    attr_writer :watcher
    attr_reader :watch_method
  end

  def self.watch_method=(method)
    case method
    when :polling
      require_relative "watcher/polling"
      @watch_method = Watcher::Polling
    when :listen
      require_relative "watcher/listen"
      @watch_method = Watcher::Listen
    else
      @watch_method = method
    end
  end

  self.watch_interval = 0.2
  self.watch_method = :polling

  def self.watcher
    @watcher ||= watch_method.new(Spring.application_root_path, watch_interval)
  end

  def self.watch(*items)
    watcher.add *items
  end
end
