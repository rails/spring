module Expedite
  module Cli
    class Server
      def run(args)
        require 'expedite/server'

        server = Expedite::Server.new(foreground: true)
        server.boot
      end

      def summary
        'Starts the expedite server'
      end
    end
  end
end
