require "spring/watcher"

# If the config/spring.rb contains requires for commands from other gems,
# then we need to be under bundler.
require "bundler/setup"

module Spring
  @commands = {}

  class << self
    attr_reader :commands
  end

  def self.register_command(name, klass)
    commands[name] = klass
  end

  def self.command?(name)
    commands.include? name
  end

  def self.command(name)
    commands.fetch name
  end

  module Commands
    class TestUnit
      def env(*)
        "test"
      end

      def call(args)
        $LOAD_PATH.unshift "test"
        args = ['test'] if args.empty?
        ARGV.replace args

        args.each do |arg|
          path = File.expand_path(arg)
          if File.directory?(path)
            Dir[File.join path, "**", "*_test.rb"].each { |f| require f }
          else
            require path
          end
        end
      end

      def description
        "Execute a Test::Unit test."
      end
    end
    Spring.register_command "testunit", TestUnit.new

    class RSpec
      def env(*)
        "test"
      end

      def call(args)
        ARGV.replace args
        $0 = "rspec"
        require 'rspec/autorun'
      end

      def description
        "Execute an RSpec spec."
      end
    end
    Spring.register_command "rspec", RSpec.new

    class Cucumber
      def env(*)
        "test"
      end

      def call(args)
        require 'cucumber'
        # Cucumber's execute funtion returns `true` if any of the steps failed or
        # some other error occured.
        Kernel.exit(1) if ::Cucumber::Cli::Main.execute(args)
      end

      def description
        "Execute a Cucumber feature."
      end
    end
    Spring.register_command "cucumber", Cucumber.new

    class Rake
      class << self
        attr_accessor :environment_matchers
      end

      self.environment_matchers = {
        /^(test|spec|cucumber)($|:)/ => "test"
      }

      def env(args)
        self.class.environment_matchers.each do |matcher, environment|
          return environment if matcher === args.first
        end
        nil
      end

      def call(args)
        require "rake"
        ARGV.replace args
        ::Rake.application.run
      end

      def description
        "Run a rake task."
      end
    end
    Spring.register_command "rake", Rake.new

    class RailsConsole
      def env(args)
        args.first if args.first && !args.first.index("-")
      end

      def setup
        require "rails/commands/console"
      end

      def call(args)
        ARGV.replace args
        ::Rails::Console.start(::Rails.application)
      end

      def description
        nil
      end
    end
    Spring.register_command "rails_console", RailsConsole.new

    class RailsGenerate
      def setup
        Rails.application.load_generators
      end

      def call(args)
        ARGV.replace args
        require "rails/commands/generate"
      end

      def description
        nil
      end
    end
    Spring.register_command "rails_generate", RailsGenerate.new

    class RailsRunner
      def env(tail)
        previous_option = nil
        tail.reverse.each do |option|
          case option
          when /--environment=(\w+)/ then return $1
          when '-e' then return previous_option
          end
          previous_option = option
        end
        nil
      end

      def call(args)
        Object.const_set(:APP_PATH, Rails.root.join('config/application'))
        ARGV.replace args
        require "rails/commands/runner"
      end

      def description
        nil
      end
    end
    Spring.register_command "rails_runner", RailsRunner.new
  end

  # Load custom commands, if any.
  # needs to be at the end to allow modification of existing commands.
  config = File.expand_path("./config/spring.rb")
  require config if File.exist?(config)
end
