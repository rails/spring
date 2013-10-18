module Spring
  module Client
    class Binstub < Command
      attr_reader :bindir, :name

      def self.description
        "Generate spring based binstubs."
      end

      def self.call(args)
        require "spring/commands"
        super
      end

      def initialize(args)
        super

        @bindir = env.root.join("bin")
        @name   = args[1]
      end

      def call
        if Spring.command?(name) || name == "rails"
          bindir.mkdir unless bindir.exist?
          generate_command_binstub
        else
          $stderr.puts "The '#{name}' command is not known to spring."
          exit 1
        end
      end

      def spring_binstub
        bindir.join("spring")
      end

      def command_binstub
        bindir.join(name)
      end

      def generate_command_binstub
        File.write(command_binstub, <<CODE)
#!/usr/bin/env bash
exec spring #{name} "$@"
CODE

        command_binstub.chmod 0755
      end
    end
  end
end
