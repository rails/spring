require "spring/version"

module Spring
  module Client
    class Stop < Command
      TIMEOUT = 2 # seconds

      def self.description
        "Stop all spring processes for this project."
      end

      def call
        if env.server_running?
          timeout = Time.now + TIMEOUT
          kill 'TERM'
          sleep 0.1 until !env.server_running? || Time.now >= timeout

          if env.server_running?
            $stderr.puts "Spring did not stop; killing forcibly."
            kill 'KILL'
          else
            puts "Spring stopped."
          end
        else
          puts "Spring is not running"
        end
      end

      def kill(sig)
        pid = env.pid
        Process.kill(sig, pid) if pid
      rescue Errno::ESRCH
        # already dead
      end
    end
  end
end
