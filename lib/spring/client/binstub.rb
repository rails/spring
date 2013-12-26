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
        def fallback(name)
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
        generate_spring_binstub
        commands.each { |name, command| generate_binstub(name, command) }
      end

      def generate_spring_binstub
        File.write(bindir.join("spring"), <<CODE)
#!/usr/bin/env ruby

unless defined?(Spring)
  require "rubygems"
  require "bundler"

  ENV["GEM_HOME"] = ""
  ENV["GEM_PATH"] = Bundler.bundle_path.to_s
  Gem.paths = ENV

  require "spring/binstub"
end
CODE

        bindir.join("spring").chmod 0755
      end

      def generate_binstub(name, command)
        File.write(bindir.join(name), <<CODE)
#!/usr/bin/env ruby

begin
  load File.expand_path("../spring", __FILE__)
rescue LoadError
end

#{command.fallback(name).strip.gsub(/^/, "  ")}
CODE

        bindir.join(name).chmod 0755
      end
    end
  end
end
