module Spring
  class << self
    attr_writer :watcher

    def watcher
      @watcher ||= begin
        if ListenWatcher.available?
          ListenWatcher.new(Spring.application_root_path, :latency => 0.2)
        else
          PollingWatcher.new
        end
      end
    end
  end
end
