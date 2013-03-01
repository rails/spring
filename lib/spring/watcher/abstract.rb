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
        @files       = []
        @directories = []
        @stale       = false
        @io_listener = nil
      end

      def add_files(new_files)
        files.concat Array(new_files).select { |f| File.exist? f }.map { |f| File.realpath f }
        files.uniq!
        subjects_changed
      end

      def add_directories(new_directories)
        directories.concat Array(new_directories).map { |d| File.realpath d }
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
