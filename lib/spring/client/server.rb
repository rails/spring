module Spring
  module Client
    class Server < Command
      def call
        require "spring/server"
        Spring::Server.boot(foreground: true)
      end

      def self.description
        "Explicitly start a Spring server in the foreground"
      end
    end
  end
end
