require "set"

module Spring
  module Client
    class Rails < Command
      COMMANDS = Set.new %w(console runner generate)

      ALIASES = {
        "c" => "console",
        "r" => "runner",
        "g" => "generate"
      }

      def self.description
        "Run a rails command. The following sub commands will use spring: #{COMMANDS.to_a.join ', '}."
      end

      def call
        command_name = ALIASES[args[1]] || args[1]

        if COMMANDS.include?(command_name)
          Run.call(["rails_#{command_name}", *args.drop(2)])
        else
          exec "bundle", "exec", *args
        end
      end
    end
  end
end
