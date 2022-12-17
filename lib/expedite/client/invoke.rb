require 'socket'

require 'expedite/client/base'

module Expedite
  module Client
    class Invoke < Base
    protected
      def run_command_method
        "invoke"
      end
    end
  end
end
