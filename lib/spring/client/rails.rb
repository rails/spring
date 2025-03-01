module Spring
  module Client
    class Rails < Command
      SPECIAL_COMMANDS = %w(test)
      EXCLUDED_COMMANDS = %w(server)

      ALIASES = {
        "t" => "test",
        "s" => "server"
      }

      def self.description
        "Run a rails command. The following sub commands will use Spring: #{COMMANDS.to_a.join ', '}."
      end

      def call
        command_name = ALIASES[args[1]] || args[1]

        if SPECIAL_COMMANDS.include?(command_name)
          Run.call(["rails_#{command_name}", *args.drop(1)])
        elsif EXCLUDED_COMMANDS.include?(command_name)
          require "spring/configuration"
          ARGV.shift
          load Dir.glob(Spring.application_root_path.join("{bin,script}/rails")).first
          exit
        else
          Run.call(["rails", *args.drop(1)])
        end
      end
    end
  end
end
