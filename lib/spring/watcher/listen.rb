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

      def initialize(root, latency)
        super
        @stale = false
      end

      def stale?
        @stale
      end

      def running?
        @listener
      end

      def start
        unless @listener
          require 'listen'
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

      def restart
        stop
        start
      end

      def watching?(file)
        files.include?(file) || file.start_with?(*directories)
      end

      def changed(modified, added, removed)
        if (modified + added + removed).any? { |f| watching? f }
          @stale = true
        end
      end
    end
  end
end
