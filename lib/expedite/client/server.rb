require 'expedite/client/base'

module Expedite
  module Client
    class Server < Base
      def initialize(env:)
        super(env: env, variant: '__server__')
      end

      def info
        call("info")
      end
    end
  end
end
