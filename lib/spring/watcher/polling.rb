require "spring/watcher/abstract"

module Spring
  module Watcher
    class Polling < Abstract
      attr_reader :mtime

      def initialize(root, latency)
        super
        @mtime  = 0
        @poller = nil
      end

      def check_stale
        synchronize do
          computed = compute_mtime
          if mtime < computed
            debug { "check_stale: mtime=#{mtime.inspect} < computed=#{computed.inspect}" }
            mark_stale
          end
        end
      end

      def add(*)
        check_stale if @poller
        super
      end

      def start
        debug { "start: poller=#{@poller.inspect}" }
        unless @poller
          @poller = Thread.new {
            Thread.current.abort_on_exception = true

            begin
              loop do
                Kernel.sleep latency
                check_stale
              end
            rescue Exception => e
              debug do
                "poller: aborted: #{e.class}: #{e}\n  #{e.backtrace.join("\n  ")}"
              end
              raise
            end
          }
        end
      end

      def stop
        debug { "stopping poller: #{@poller.inspect}" }
        if @poller
          @poller.kill
          @poller = nil
        end
      end

      def subjects_changed
        computed = compute_mtime
        debug { "subjects_changed: mtime #{@mtime} -> #{computed}" }
        @mtime = computed
      end

      private

      def compute_mtime
        expanded_files.map { |f| File.mtime(f).to_f }.max || 0
      rescue Errno::ENOENT
        # if a file does no longer exist, the watcher is always stale.
        Float::MAX
      end

      def expanded_files
        files + Dir["{#{directories.map { |d| "#{d}/**/*" }.join(",")}}"]
      end
    end
  end
end
