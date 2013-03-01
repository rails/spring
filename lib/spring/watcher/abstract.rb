require "set"

module Spring
  module Watcher
    # A user of a watcher can use IO.select to wait for changes:
    #
    #   watcher = MyWatcher.new(root, latency)
    #   IO.select([watcher]) # watcher is running in background
    #   watcher.stale? # => true
    class Abstract
      attr_reader :files, :directories, :root, :latency

      def initialize(root, latency)
        @root        = File.realpath(root)
        @latency     = latency
        @files       = Set.new
        @directories = Set.new
        @stale       = false
        @io_listener = nil
      end

      def add(*items)
        items.flatten.each do |item|
          next unless File.exist? item
          item = File.realpath item

          if File.directory?(item)
            directories << item
          else
            files << item
          end
        end

        subjects_changed
      end

      def stale?
        @stale
      end

      def mark_stale
        @stale = true
        @io_listener.write "." if @io_listener
      end

      def to_io
        read, write = IO.pipe
        @io_listener = write
        read
      end

      def restart
        stop
        start
      end

      def start
        raise NotImplementedError
      end

      def stop
        raise NotImplementedError
      end

      def subjects_changed
        raise NotImplementedError
      end
    end
  end
end
