require "spring/version"

module Spring
  module Client
    class Stop < Command
      def call
        Process.kill('SIGTERM', env.pid) if env.pid
      end
    end
  end
end
