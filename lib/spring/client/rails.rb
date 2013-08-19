require "set"

module Spring
  module Client
    class Rails < Command
      COMMANDS = Set.new %w(console runner generate destroy)

      ALIASES = {
        "c" => "console",
        "r" => "runner",
        "g" => "generate",
        "d" => "destroy"
      }

      def self.description
        "Run a rails command. The following sub commands will use spring: #{COMMANDS.to_a.join ', '}."
      end

      def call
        command_name = ALIASES[args[1]] || args[1]

        if COMMANDS.include?(command_name)
          Run.call(["rails_#{command_name}", *args.drop(2)])
        else
          require "spring/configuration"
          ARGV.shift
          Object.const_set(:APP_PATH, Spring.application_root_path.join("config/application").to_s)
          require Spring.application_root_path.join("config/boot")
          require "rails/commands"
        end
      end
    end
  end
end
