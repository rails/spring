require 'expedite/client/exec'
require 'expedite/client/invoke'
require 'expedite/syntax'

module Expedite
  class AgentProxy
    attr_accessor :env, :agent

    def initialize(env:, agent:)
      self.env = env
      self.agent = agent
    end

    def exec(*args)
      Client::Exec.new(env: env, agent: agent).call(*args)
    end

    def invoke(*args)
      Client::Invoke.new(env: env, agent: agent).call(*args)
    end
  end
end

module Expedite
  ##
  # Returns a client to dispatch actions to the specified agent
  def self.agent(agent)
    @clients ||= Hash.new do |h, k|
      AgentProxy.new(env: Env.new, agent: agent)
    end
    @clients[agent]
  end
end


