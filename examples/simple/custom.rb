
module Expedite
  module Command
    class Custom
      def call
        puts "[#{Expedite.variant}] sleeping for 5"
        puts "$sleep_parent = #{$sleep_parent}"
        puts "$sleep_child = #{$sleep_child}"
        puts "[#{Expedite.variant}] done"
      end

      def exec_name
        "custom"
      end

      def setup(client)
      end
    end
  end
end
