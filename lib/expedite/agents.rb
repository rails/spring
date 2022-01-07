
module Expedite
  # Definition of a Agent
  class Agent
    ##
    # Name of the parent agent. This allows you to create agents from
    # an existing agent.
    # Defaults to nil.
    attr_accessor :parent

    ##
    # If set to true, agent will be restarted automatically if it is killed.
    # Defaults to false.
    attr_accessor :keep_alive

    ##
    # [parent] Name of parent agent.
    # [keep_alive] Specifies if the agent should be automatically restarted if it is terminated. Defaults to false.
    # [after_fork] Block is executed when agent is first preloaded.
    def initialize(parent: nil, keep_alive: false, &after_fork)
      @parent = parent
      @keep_alive = keep_alive
      @after_fork_proc = after_fork
    end

    ##
    # Called when agent if first preloaded. This version calls the after_fork
    # block provided in the initializer.
    def after_fork(agent)
      @after_fork_proc&.call(agent)
    end
  end

  class Agents
    Registration = Struct.new(:matcher, :agent) do
      def match?(name)
        File.fnmatch?(matcher, name.to_s)
      end
    end

    def self.current
      @current ||= Agents.new
    end

    ##
    # Retrieves the specified agent
    def self.lookup(agent)
      self.current.lookup(agent.to_s)
    end

    ##
    # Registers a agent. Agents are matched in the
    # order they are registered.
    #
    # [matcher] Wildcard to match a name against.
    # [named_options] Agent options.
    # [after_fork] Optional block that is called when
    #              agent is preloaded.
    #
    # = Example
    #   Expedite::Agents.register('base' do |name|
    #     puts "Base #{name} started"
    #   end
    #   Expedite::Agents.register('development/abc', parent: 'base') do |name|
    #     puts "Agent #{name} started"
    #   end
    def self.register(matcher, **named_options, &after_fork)
      self.current.register(matcher.to_s, **named_options, &after_fork)
    end

    ##
    # Resets registrations to default
    def self.reset
      self.current.reset
    end

    def initialize
      @registrations = []
    end

    def lookup(agent)
      ret = @registrations.find do |r|
        r.match?(agent)
      end
      raise NotImplementedError, "Agent #{agent.inspect} not found" if ret.nil?
      ret.agent
    end

    def register(matcher, **named_options, &after_fork)
      @registrations << Registration.new(
        matcher,
        Agent.new(**named_options, &after_fork)
      )
    end

    def reset
      @registrations = []
      nil
    end
  end
end
