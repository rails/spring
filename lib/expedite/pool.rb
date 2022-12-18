require "expedite/client"

module Expedite
  def self.pool(variant)
    @pools ||= Hash.new do |h, k|
      Client.new(env: Env.new, variant: variant)
    end
    @pools[variant]
  end
end

