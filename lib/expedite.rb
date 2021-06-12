require 'expedite/client/exec'
require 'expedite/client/server'

module Expedite
  ##
  # Returns a client to dispatch actions to the specified variant
  def self.variant(variant)
    @clients ||= Hash.new do |h, k|
      Client::Exec.new(env: Env.new, variant: variant)
    end
    @clients[variant]
  end

  ##
  # Alias for self.variant
  def self.v(variant)
    self.variant(variant)
  end

  def self.server
    @server = Client::Server.new(env: Env.new)
  end
end

