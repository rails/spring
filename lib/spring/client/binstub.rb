module Spring
  module Client
    class Binstub < Command
      attr_reader :bindir, :name, :command

      def self.description
        "Generate spring based binstubs."
      end

      def self.call(args)
        require "spring/commands"
        super
      end

      def initialize(args)
        super

        @bindir  = env.root.join("bin")
        @name    = args[1]
        @command = Spring.commands[name]
      end

      def call
        if command || name == "rails"
          bindir.mkdir unless bindir.exist?
          generate_binstub
        else
          $stderr.puts "The '#{name}' command is not known to spring."
          exit 1
        end
      end

      def binstub
        bindir.join(name)
      end

      def generate_binstub
        File.write(binstub, <<CODE)
#!/usr/bin/env ruby

if !Process.respond_to?(:fork) || Gem::Specification.find_all_by_name("spring").empty?
#{fallback.strip.gsub(/^/, "  ")}
else
  ARGV.unshift "#{name}"
  load Gem.bin_path("spring", "spring")
end
CODE

        binstub.chmod 0755
      end

      def fallback
        if command.respond_to?(:fallback)
          command.fallback
        elsif name == "rails"
          <<CODE
APP_PATH = File.expand_path('../../config/application',  __FILE__)
require_relative '../config/boot'
require 'rails/commands'
CODE
        else
          %{exec "bundle", "exec", "#{name}", *ARGV}
        end
      end
    end
  end
end
