
module Expedite
  class Variant
    attr_accessor :parent

    ##
    # [parent] Name of parent variant.
    # [after_fork] Block is executed when variant is first preloaded.
    def initialize(parent: nil, &after_fork)
      @parent = parent
      @after_fork_proc = after_fork
    end

    ##
    # Called when variant if first preloaded. This version calls the after_fork
    # block provided in the initializer.
    def after_fork(variant)
      @after_fork_proc&.call(variant)
    end
  end

  class Variants
    Registration = Struct.new(:matcher, :variant) do
      def match?(name)
        File.fnmatch?(matcher, name)
      end
    end

    def self.current
      @current ||= Variants.new
    end

    ##
    # Retrieves the specified variant
    def self.lookup(variant)
      self.current.lookup(variant)
    end

    ##
    # Registers a variant. Variants are matched in the
    # order they are registered.
    #
    # [matcher] Wildcard to match a name against.
    # [named_options] Variant options.
    # [after_fork] Optional block that is called when
    #              variant is preloaded.
    #
    # = Example
    #   Expedite::Variants.register('base' do |name|
    #     puts "Base #{name} started"
    #   end
    #   Expedite::Variants.register('development/abc', parent: 'base') do |name|
    #     puts "Variant #{name} started"
    #   end
    def self.register(matcher, **named_options, &after_fork)
      self.current.register(matcher, **named_options, &after_fork)
    end

    ##
    # Resets registrations to default
    def self.reset
      self.current.reset
    end

    def initialize
      @registrations = []
    end

    def lookup(variant)
      ret = @registrations.find do |r|
        r.match?(variant)
      end
      raise NotImplementedError, "Variant #{variant.inspect} not found" if ret.nil?
      ret.variant
    end

    def register(matcher, **named_options, &after_fork)
      @registrations << Registration.new(
        matcher,
        Variant.new(**named_options, &after_fork)
      )
    end

    def reset
      @registrations = {}
      nil
    end
  end
end
