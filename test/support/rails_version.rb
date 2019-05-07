module Spring
  module Test
    class RailsVersion
      attr_reader :version

      def initialize(string)
        @version = Gem::Version.new(string)
      end

      def major
        version.segments[0]
      end

      def minor
        version.segments[1]
      end

      def to_s
        version.to_s
      end
    end
  end
end
