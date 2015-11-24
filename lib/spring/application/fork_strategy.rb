module Spring
  class Application
    module ForkStrategy
      def eager_preload
        with_pty { preload }
      end

      def with_pty
        PTY.open do |master, slave|
          [STDOUT, STDERR, STDIN].each { |s| s.reopen slave }
          Thread.new { master.read }
          yield
          reset_streams
        end
      end

      def wait(pid, streams, client)
        @mutex.synchronize { @waiting << pid }

        # Wait in a separate thread so we can run multiple commands at once
        Thread.new {
          begin
            _, status = Process.wait2 pid
            log "#{pid} exited with #{status.exitstatus}"

            streams.each(&:close)
            client.puts(status.exitstatus)
            client.close
          ensure
            @mutex.synchronize { @waiting.delete pid }
            exit_if_finished
          end
        }
      end

      def start_app(client, streams, app_started)
        pid = fork { yield }
        app_started[0] = true

        disconnect_database
        reset_streams

        log "forked #{pid}"
        manager.puts pid

        wait pid, streams, client
      end
    end
  end
end
