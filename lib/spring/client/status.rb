module Spring
  module Client
    class Status < Command
      def self.description
        "Show current status."
      end

      def call
        if env.server_running?
          puts "Spring is running:"
          puts
          puts `ps -p #{env.pid} --ppid #{env.pid} -o pid= -o cmd=`
        else
          puts "Spring is not running."
        end
      end
    end
  end
end
