
module Expedite
  Variant = Struct.new(:parent, keyword_init: true)

  class Variants
    def self.current
      @current ||= Variants.new
    end

    def self.lookup(variant)
      self.current.lookup(variant)
    end

    def self.register(matcher, **named_options)
      self.current.register(matcher, **named_options)
    end

    def initialize
      @variants = {}
    end

    def register(matcher, **named_options)
      @variants[matcher] = if block_given?
        yield
      else
        Variant.new(named_options)
      end
    end

    def lookup(matcher)
      ret = @variants[matcher]
      raise NotImplementedError, "Variant '#{matcher.inspect}' not found" if ret.nil?
      ret
    end
  end
end
