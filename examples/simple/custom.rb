
module Expedite
  module Command
    class Custom
      def call
        puts "[#{ENV['EXPEDITE_VARIANT']}] sleeping for 5"
        puts "$sleep_parent = #{$sleep_parent}"
        puts "$sleep_child = #{$sleep_child}"
        puts "[#{ENV['EXPEDITE_VARIANT']}] done"
      end

      def exec_name
        "custom"
      end

      def setup(client)
      end
    end
  end
end
