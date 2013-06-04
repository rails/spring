module Spring
  module Watcher
    class Listen < Abstract
      attr_reader :listener

      def self.available?
        require "listen"
        require "listen/version"
        true
      rescue LoadError
        false
      end

      def listen_klass
        if ::Listen::VERSION >= "1.0.0"
          ::Listen::Listener
        else
          ::Listen::MultiListener
        end
      end

      def start
        unless @listener
          @listener = listen_klass.new(*base_directories, relative_paths: false)
          @listener.latency(latency)
          @listener.change(&method(:changed))

          if ::Listen::VERSION >= "1.0.0"
            @listener.start
          else
            @listener.start(false)
          end
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
