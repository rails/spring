require 'expedite/action/block'
require 'expedite/action/boot'

module Expedite
  class Actions
    def self.current
      @current ||= Actions.new
    end

    def self.lookup(name)
      self.current.lookup(name)
    end

    ##
    # Registers an action. If multiple actions are registered with the
    # same name, the last one takes precedence.
    #
    # [name] Name of the action. Expedite internal actions are prefixed
    #        with "expedite/"
    # [klass_or_nil] Class of the action. If omitted, will default to
    #                Expedite::Action::Block.
    # [named_options] Action options. Passed to the initializer.
    def self.register(name, klass_or_nil = nil, **named_options, &block)
      self.current.register(name.to_s, klass_or_nil, **named_options, &block)
    end

    ##
    # Restores existing registrations to default
    def self.reset
      self.current.reset
    end

    def initialize
      reset
    end

    def lookup(name)
       ret = @registrations[name]
       raise NotImplementedError, "Action #{name.inspect} not found" if ret.nil?
       ret
    end

    def register(name, klass_or_nil = nil, **named_options, &block)
      cmd = if klass_or_nil.nil?
        Action::Block.new(**named_options, &block)
      else
        klass_or_nil.new(**named_options)
      end

      @registrations[name] = cmd
    end

    def reset
      @registrations = {}

      # Default registrations
      register("expedite/boot", Expedite::Action::Boot)

      nil
    end
  end
end
