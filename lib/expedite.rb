require "expedite/client"

module Expedite
  ##
  # Returns a client to dispatch actions to the specified variant
  def self.variant(variant)
    @clients ||= Hash.new do |h, k|
      Client.new(env: Env.new, variant: variant)
    end
    @clients[variant]
  end

  ##
  # Alias for self.variant
  def self.v(variant)
    self.variant(variant)
  end
end

