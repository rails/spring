module Spring
  module Watcher
    class Abstract
      attr_reader :files, :directories, :root, :latency

      def initialize(root, latency)
        @root        = File.realpath(root)
        @latency     = latency
        @files       = []
        @directories = []
      end

      def add_files(new_files)
        files.concat Array(new_files).select { |f| File.exist? f }.map { |f| File.realpath f }
        files.uniq!

        # FIXME: Be intelligent about when to restart, as it's expensive
        #        with the Listen watcher.
        restart if running?
      end

      def add_directories(new_directories)
        directories.concat Array(new_directories).map { |d| File.realpath d }
        restart if running?
      end

      def start
        raise NotImplementedError
      end

      def restart
        raise NotImplementedError
      end

      def stale?
        raise NotImplementedError
      end

      def running?
        raise NotImplementedError
      end
    end
  end
end
