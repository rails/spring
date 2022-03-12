require 'set'
require 'expedite/server/agent_manager'

module Expedite
  module Server
    class AgentPool
      def initialize(name, env)
        @name = name
        @env = env
        @checked_in = []
        @checked_out = Set.new
      end

      # Get a free agent from the pool
      def checkout
        agent = @checked_in.pop

        agent = build_agent if agent.nil?
        @checked_out.add(agent)

        agent
      end

      def checkin(agent)
        @checked_out.delete(agent)
        @checked_in.push(agent)
      end

      def build_agent
        Server::AgentManager.new(@name, @env)
      end

      # Returns all agents, both checked in and checked out
      def all
        @checked_in + @checked_out.to_a
      end
    end
  end
end
