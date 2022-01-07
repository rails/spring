require 'expedite/actions'
require 'expedite/agents'

module Expedite
  module Syntax
    def define(&block)
      DSL.run(&block)
    end
    
    class DSL
      def action(name, &block)
        Expedite::Actions.register(name, &block)
      end

      def agent(name, parent:nil, &block)
        Expedite::Agents.register(name, parent: parent, &block)
      end

      def self.run(&block)
        new.instance_eval(&block)
      end
    end
  end

  extend Syntax
end