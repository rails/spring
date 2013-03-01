require "set"
require "pathname"
require "mutex_m"

module Spring
  module Watcher
    # A user of a watcher can use IO.select to wait for changes:
    #
    #   watcher = MyWatcher.new(root, latency)
    #   IO.select([watcher]) # watcher is running in background
    #   watcher.stale? # => true
    class Abstract
      include Mutex_m

      attr_reader :files, :directories, :root, :latency

      def initialize(root, latency)
        super()

        @root        = File.realpath(root)
        @latency     = latency
        @files       = Set.new
        @directories = Set.new
        @stale       = false
        @io_listener = nil
      end

      def add(*items)
        items = items.flatten.map do |item|
          item = Pathname.new(item)

          if item.relative?
            Pathname.new("#{root}/#{item}")
          else
            item
          end
        end

        items.each do |item|
          if item.directory?
            directories << item.realpath.to_s
          else
            files << item.realpath.to_s
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
