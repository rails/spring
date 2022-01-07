
module Expedite
  module Action
    class Block
      attr_reader :runs_in
      
      def initialize(runs_in: :application, &block)
        @runs_in = runs_in
        @block = block
      end

      def call(*args)
        @block.call(*args)
      end

      def setup(_)
      end
    end
  end
end
