require 'expedite/command/basic'
require 'expedite/command/boot'

module Expedite
  class Commands
    def self.current
      @current ||= Commands.new
    end

    def self.lookup(name)
      self.current.lookup(name)
    end

    ##
    # Registers a command. If multiple commands are registered with the
    # same name, the last one takes precedence.
    #
    # [name] Name of the command. Expedite internal commands are prefixed
    #        with "expedite/"
    # [klass_or_nil] Class of the command. If omitted, will default to
    #                Expedite::Command::Basic.
    # [named_options] Command options. Passed to the initializer.
    def self.register(name, klass_or_nil = nil, **named_options, &block)
      self.current.register(name, klass_or_nil, **named_options, &block)
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
       raise NotImplementedError, "Command #{name.inspect} not found" if ret.nil?
       ret
    end

    def register(name, klass_or_nil = nil, **named_options, &block)
      cmd = if klass_or_nil.nil?
        Command::Basic.new(**named_options, &block)
      else
        klass_or_nil.new(**named_options)
      end

      @registrations[name] = cmd
    end

    def reset
      @registrations = {}

      # Default registrations
      register("expedite/boot", Expedite::Command::Boot)

      nil
    end
  end
end
