module Spring
  module Client
    class Server < Command
      def self.description
        "Explicitly start a Spring server in the foreground"
      end

      def call
        require "spring/server"
        Spring::Server.boot(
          foreground: foreground?,
          eager_preload: eager_preload?,
        )
      end

      def foreground?
        !args.include?("--background")
      end

      def eager_preload?
        args.include?("--eager-preload")
      end
    end
  end
end
