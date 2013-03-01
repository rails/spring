module Spring
  module Watcher
    class Listen < Abstract
      attr_reader :listener

      def self.available?
        require "listen"
        true
      rescue LoadError
        false
      end

      def start
        unless @listener
          @listener = ::Listen::MultiListener.new(*base_directories)
          @listener.latency(latency)
          @listener.change(&method(:changed))
          @listener.start(false)
        end
      end

      def stop
        if @listener
          @listener.stop
          @listener = nil
        end
      end

      def subjects_changed
        if @listener && @listener.directories.sort != base_directories.sort
          restart
        end
      end

      def watching?(file)
        files.include?(file) || file.start_with?(*directories)
      end

      def changed(modified, added, removed)
        synchronize do
          if (modified + added + removed).any? { |f| watching? f }
            mark_stale
          end
        end
      end

      def base_directories
        [root] +
          files.reject       { |f| f.start_with? root }.map { |f| File.expand_path("#{f}/..") } +
          directories.reject { |d| d.start_with? root }
      end
    end
  end
end
