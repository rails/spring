module Spring
  module Client
    class Start < Command
      def self.description
        "Boot the spring server (this happens automatically when you run a command)"
      end

      def call
        # Require spring/server before bundler so that it doesn't have to be in
        # the bundle
        require "spring/server"
        require "bundler/setup"
        Spring::Server.boot
      end
    end
  end
end
