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

require "rubygems"
require "bundler"

ENV["GEM_HOME"] = ""
ENV["GEM_PATH"] = Bundler.bundle_path.to_s
Gem.paths = ENV

if Process.respond_to?(:fork) && !Gem::Specification.find_all_by_name("spring").empty?
  module Spring
    def self.invoke
      load Gem.bin_path("spring", "spring")
    end
  end
end

if $0 == __FILE__
  if defined?(Spring.invoke)
    Spring.invoke
  else
    $stderr.puts "Spring is not available. Ensure the gem is installed and your Ruby implementation supports Process.fork."
    exit 1
  end
end
CODE

        bindir.join("spring").chmod 0755
      end

      def generate_binstub(name, command)
        File.write(bindir.join(name), <<CODE)
#!/usr/bin/env ruby

load File.expand_path('../spring', __FILE__)

if defined?(Spring.invoke)
  ARGV.unshift "#{name}"
  Spring.invoke
else
#{command.fallback(name).strip.gsub(/^/, "  ")}
end
CODE

        bindir.join(name).chmod 0755
      end
    end
  end
end
