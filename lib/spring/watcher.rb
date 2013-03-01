module Spring
  class << self
    attr_writer :watcher

    def watcher
      @watcher ||= watcher_class.new(Spring.application_root_path, :latency => 0.2)
    end

    def watcher_class
      if ListenWatcher.available?
        ListenWatcher
      else
        PollingWatcher
      end
    end
  end
end
