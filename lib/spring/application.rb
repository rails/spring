require "spring/boot"
require "set"
require "pty"
require "spring/platform"
require "spring/application/base"
require "spring/application/pool_strategy"
require "spring/application/fork_strategy"

module Spring
  module Application
    def self.create(*args)
      strategy = Spring.fork? ? ForkStrategy : PoolStrategy
      strategy.new(*args)
    end
  end
end
