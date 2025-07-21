module Spring
  module Commands
    class Rails
      def call
        load Dir.glob(::Rails.root.join("{bin,script}/rails")).first
      end

      def env(args)
        environment = nil

        args.each.with_index do |arg, i|
          if arg =~ /(-e|--environment)=(\w+)/
            environment = $2
          elsif i > 0 && %w[-e --environment].include?(args[i - 1])
            environment = arg
          end
        end

        environment
      end

      def description
        nil
      end
    end

    class RailsTest < Rails
      def env(args)
        super || "test"
      end
    end

    Spring.register_command "rails",          Rails.new
    Spring.register_command "rails_test",     RailsTest.new
  end
end
