require 'expedite/client/base'

module Expedite
  module Client
    class Server < Base
      def initialize(env:)
        super(env: env, variant: '__server__')
      end

      def application_pids
        call("application_pids")
      end
    end
  end
end
