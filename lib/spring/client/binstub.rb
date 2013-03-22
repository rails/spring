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
          generate_spring_binstub
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

      def generate_spring_binstub
        File.write(spring_binstub, <<'CODE')
#!/usr/bin/env ruby

# This is a special way of invoking the spring gem in order to
# work around the performance issue discussed in
# https://github.com/rubygems/rubygems/pull/435

glob       = "{#{Gem::Specification.dirs.join(",")}}/spring-*.gemspec"
candidates = Dir[glob].to_a.sort

spec = Gem::Specification.load(candidates.last)

if spec
  spec.activate
  load spec.bin_file("spring")
else
  $stderr.puts "Could not find spring gem in #{Gem::Specification.dirs.join(", ")}."
  exit 1
end
CODE

        spring_binstub.chmod 0755
      end

      def generate_command_binstub
        File.write(command_binstub, <<CODE)
#!/usr/bin/env bash
exec $(dirname $0)/spring #{name} "$@"
CODE

        command_binstub.chmod 0755
      end
    end
  end
end
