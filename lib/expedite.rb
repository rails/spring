require 'expedite/client/exec'
require 'expedite/client/invoke'
require 'expedite/client/server'

module Expedite
  class VariantProxy
    attr_accessor :env, :variant

    def initialize(env:, variant:)
      self.env = env
      self.variant = variant
    end

    def exec(*args)
      Client::Exec.new(env: env, variant: variant).call(*args)
    end

    def invoke(*args)
      Client::Invoke.new(env: env, variant: variant).call(*args)
    end
  end
end

module Expedite
  ##
  # Returns a client to dispatch actions to the specified variant
  def self.variant(variant)
    @clients ||= Hash.new do |h, k|
      VariantProxy.new(env: Env.new, variant: variant)
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

