module Spring
  module Watcher
    class Listen < Abstract
      attr_reader :listener

      def self.available?
        require 'listen'
        true
      rescue LoadError
        false
      end

      def running?
        @listener
      end

      def start
        unless @listener
          @listener = ::Listen.to(root, latency: latency).change(&method(:changed))
          @listener.start(false)
        end
      end

      def stop
        if @listener
          @listener.stop
          @listener = nil
        end
      end

      def watching?(file)
        files.include?(file) || file.start_with?(*directories)
      end

      def changed(modified, added, removed)
        if (modified + added + removed).any? { |f| watching? f }
          mark_stale
        end
      end
    end
  end
end
