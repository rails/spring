require "spring/version"

module Spring
  module Client
    class Help < Command
      attr_reader :spring_commands, :application_commands

      def self.description
        "Print available commands."
      end

      def initialize(args, spring_commands = nil, application_commands = nil)
        super args

        @spring_commands      = spring_commands       || Spring::Client::COMMANDS
        @application_commands = application_commands  || Spring.commands
      end

      def call
        puts formatted_help
      end

      def formatted_help
        ["Usage: spring COMMAND [ARGS]\n",
         *spring_command_help,
         '',
         *application_command_help].join("\n")
      end

      def spring_command_help
        ["Commands for spring itself:\n",
        *client_commands.map { |c,n| display_value(c,n) }]
      end

      def application_command_help
        ["Commands for your application:\n",
        *registered_commands.map { |c,n| display_value(c,n) }]
      end

      private

      def client_commands
        spring_commands.invert
      end

      def registered_commands
        Hash[unique_commands.collect { |c| [c, command_aliases(c)] }]
      end

      def all_commands
        @all_commands ||= client_commands.merge(registered_commands)
      end

      def unique_commands
        application_commands.collect { |k,v| v }.uniq
      end

      def command_aliases(command)
        spring_commands.merge(application_commands).select { |k,v| v == command }.keys
      end

      def description_for_command(command)
        if command.respond_to?(:description)
          command.description
        else
          "No description given."
        end
      end

      def display_value(command, names)
        "  #{ Array(names).join(', ').ljust(max_name_width) }  #{ description_for_command(command) }"
      end

      def max_name_width
        @max_name_width ||= all_commands.collect { |_,n| Array(n).join(', ').length }.max
      end
    end
  end
end
