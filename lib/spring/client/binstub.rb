module Spring
  module Client
    class Binstub < Command
      attr_reader :bindir, :commands

      def self.description
        "Generate spring based binstubs. Use --all to generate a binstub for all known commands."
      end

      def self.call(args)
        require "spring/commands"
        super
      end

      class RailsCommand
        def fallback
          <<CODE
APP_PATH = File.expand_path('../../config/application',  __FILE__)
require_relative '../config/boot'
require 'rails/commands'
CODE
        end
      end

      def initialize(args)
        super

        @bindir   = env.root.join("bin")
        @commands = args.drop(1).inject({}) { |mem, name| mem.merge(find_commands(name)) }
      end

      def find_commands(name)
        case name
        when "--all"
          commands = Spring.commands
          commands.delete_if { |name, _| name.start_with?("rails_") }
          commands["rails"] = RailsCommand.new
          commands
        when "rails"
          { name => RailsCommand.new }
        else
          if command = Spring.commands[name]
            { name => command }
          else
            $stderr.puts "The '#{name}' command is not known to spring."
            exit 1
          end
        end
      end

      def call
        bindir.mkdir unless bindir.exist?
        commands.each { |name, command| generate_binstub(name, command) }
      end

      def generate_binstub(name, command)
        File.write(bindir.join(name), <<CODE)
#!/usr/bin/env ruby

if !Process.respond_to?(:fork) || Gem::Specification.find_all_by_name("spring").empty?
#{fallback(name, command).strip.gsub(/^/, "  ")}
else
  ARGV.unshift "#{name}"
  load Gem.bin_path("spring", "spring")
end
CODE

        bindir.join(name).chmod 0755
      end

      def fallback(name, command)
        if command.respond_to?(:fallback)
          command.fallback
        else
          %{exec "bundle", "exec", "#{name}", *ARGV}
        end
      end
    end
  end
end
