require 'expedite/server/agent_pool'

module Expedite
  module Server
    class ApplicationManager
      attr_reader :pools

      def initialize(env)
        @env = env
        @pools = Hash.new do |h, k|
          h[k] = AgentPool.new(k, @env)
        end
      end

      def with(name)
        pool = @pools[name]
        target = pool.checkout
        begin
          ret = yield target
        ensure
          pool.checkin(target)
        end
        ret
      end
    end
  end
end
