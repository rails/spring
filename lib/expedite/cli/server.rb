module Expedite
  module Cli
    class Server
      def run(args)
        require 'expedite/server/controller'

        server = Expedite::Server::Controller.new(foreground: true)
        server.boot
      end

      def summary
        'Starts the expedite server'
      end
    end
  end
end
