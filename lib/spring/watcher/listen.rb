gem "listen", "~> 1.0"
require "listen"
require "listen/version"

module Spring
  module Watcher
    class Listen < Abstract
      attr_reader :listener

      def start
        unless @listener
          @listener = ::Listen.to(*base_directories, relative_paths: false)
          @listener.latency(latency)
          @listener.change(&method(:changed))
          @listener.start
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
        ([root] +
          files.reject       { |f| f.start_with? root }.map { |f| File.expand_path("#{f}/..") } +
          directories.reject { |d| d.start_with? root }
        ).uniq
      end
    end
  end
end
