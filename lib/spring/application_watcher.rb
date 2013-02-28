module Spring
  class << self
    attr_accessor :application_watcher
  end

  self.application_watcher = begin
                               watcher_class = if ListenWatcher.available? && 0 > 1
                                                 ListenWatcher
                                               else
                                                 PollingWatcher
                                               end

                               watcher_class.new(Spring.application_root_path, :latency => 0.2)
                             end

end
