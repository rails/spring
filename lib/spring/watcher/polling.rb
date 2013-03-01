module Spring
  module Watcher
    class Polling < Abstract
      attr_reader :mtime

      def initialize(root, latency)
        super
        @mtime = nil
      end

      def restart
        @mtime = compute_mtime
      end
      alias start restart

      def stale?
        mtime < compute_mtime
      end

      def running?
        true
      end

      private

      def compute_mtime
        expanded_files.map { |f| File.mtime(f).to_f }.max || 0
      rescue Errno::ENOENT
        # if a file does no longer exist, the watcher is always stale.
        Float::MAX
      end

      def expanded_files
        files + Dir["{#{directories.join(",")}}"]
      end
    end
  end
end
