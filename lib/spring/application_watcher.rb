module Spring
  class << self
    attr_writer :application_watcher

    def application_watcher
      @application_watcher ||= begin
                               watcher_class = if ListenWatcher.available?
                                                 ListenWatcher
                                               else
                                                 PollingWatcher
                                               end

                               watcher_class.new(Spring.application_root_path, :latency => 0.2)
                             end

    end
  end
end
