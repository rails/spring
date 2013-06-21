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

      def call
        $LOAD_PATH.unshift "test"
        ARGV << "test" if ARGV.empty?
        ARGV.each { |arg| require_test(File.expand_path(arg)) }
      end

      def require_test(path)
        if File.directory?(path)
          Dir[File.join path, "**", "*_test.rb"].each { |f| require f }
        else
          require path
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

      def exec_name
        "rspec"
      end
    end
    Spring.register_command "rspec", RSpec.new

    class Cucumber
      def env(*)
        "test"
      end

      def exec_name
        "cucumber"
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

      def exec_name
        "rake"
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

      def call
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

      def call
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

      def call
        Object.const_set(:APP_PATH, Rails.root.join('config/application'))
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
