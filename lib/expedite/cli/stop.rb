module Expedite
  module Cli
    class Stop
      def run(args)
        require 'expedite/server'

        server = Expedite::Server.new
        server.stop
      end

      def summary
        'Stops the expedite server'
      end
    end
  end
end
