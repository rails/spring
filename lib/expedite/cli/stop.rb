module Expedite
  module Cli
    class Stop
      def run(args)
        require 'expedite/server/controller'

        ctrl = Expedite::Server::Controller.new
        ctrl.stop
      end

      def summary
        'Stops the expedite server'
      end
    end
  end
end
