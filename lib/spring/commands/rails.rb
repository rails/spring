module Spring
  module Commands
    class Rails
      def call
        ARGV.unshift command_name
        load Dir.glob(::Rails.root.join("{bin,script}/rails")).first
      end

      def description
        nil
      end
    end

    class RailsConsole < Rails
      def env(args)
        args.first if args.first && !args.first.index("-")
      end

      def command_name
        "console"
      end
    end

    class RailsGenerate < Rails
      def command_name
        "generate"
      end
    end

    class RailsDestroy < Rails
      def command_name
        "destroy"
      end
    end

    class RailsRunner < Rails
      def env(tail)
        previous_option = nil
        tail.reverse.each do |option|
          case option
          when /--environment=(\w+)/ then return $1
          when '-e' then return previous_option
          end
          previous_option = option
        end
        nil
      end

      def command_name
        "runner"
      end
    end

    Spring.register_command "rails_console",  RailsConsole.new
    Spring.register_command "rails_generate", RailsGenerate.new
    Spring.register_command "rails_destroy",  RailsDestroy.new
    Spring.register_command "rails_runner",   RailsRunner.new
  end
end
