module Spring
  class Application
    module PoolStrategy
      def eager_preload
        reset_streams
        preload
      end

      def start_app(client, streams, app_started)
        app_started[0] = true
        exitstatus = 0
        manager.puts Process.pid
        begin
          log "started #{Process.pid}"
          yield
        rescue SystemExit => ex
          exitstatus = ex.status
        end

        log "#{Process.pid} exited with #{exitstatus}"

        streams.each(&:close)
        client.puts(exitstatus)
        client.close

        exit
      end
    end
  end
end
