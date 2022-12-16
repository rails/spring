module Expedite
  module Cli
    class Rails
      def run(args)
        Expedite.agent(:rails_environment).exec(:rails_commands, args)
      end

      def summary
        'Starts the expedite server'
      end
    end
  end
end
