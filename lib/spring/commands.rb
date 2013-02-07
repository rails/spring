module Spring
  @commands = {}

  class << self
    attr_reader :commands
  end

  def self.register_command(name, klass, options = {})
    commands[name] = klass

    if options[:alias]
      commands[options[:alias]] = klass
    end
  end

  def self.command?(name)
    commands.include? name
  end

  def self.command(name)
    commands.fetch name
  end

  # Load custom commands, if any
  config = File.expand_path("./config/spring.rb")
  require config if File.exist?(config)

  module Commands
    class Test
      def env
        "test"
      end

      def setup
        $LOAD_PATH.unshift "test"
        require "test_helper"
      end

      def call(args)
        if args.size > 0
          ARGV.replace args
          path = File.expand_path(args.first)

          if File.directory?(path)
            Dir[File.join path, "**", "*_test.rb"].each { |f| require f }
          else
            require path
          end
        else
          $stderr.puts "you need to specify what test to run: spring test TEST_NAME"
        end
      end
    end
    Spring.register_command "test", Test.new

    class RSpec
      def env
        "test"
      end

      def setup
        $LOAD_PATH.unshift "spec"
        require "spec_helper"
      end

      def call(args)
        $0 = "rspec"
        ::RSpec::Core::Runner.run(args)
      end
    end
    Spring.register_command "rspec", RSpec.new

    class Cucumber
      def env
        "test"
      end

      def setup
        require 'cucumber'
      end

      def call(args)
        ::Cucumber::Cli::Main.execute(args)
      end
    end
    Spring.register_command "cucumber", Cucumber.new

    class Rake
      def setup
        require "rake"
      end

      def call(args)
        ARGV.replace args
        ::Rake.application.run
      end
    end
    Spring.register_command "rake", Rake.new

    class Console
      def call(args)
        # This cannot be preloaded as it messes up the IRB prompt on OS X
        # for unknown reasons. See discussion in issue #34.
        require "rails/commands/console"

        ARGV.replace args
        ::Rails::Console.start(::Rails.application)
      end
    end
    Spring.register_command "console", Console.new, alias: "c"

    class Generate
      def setup
        Rails.application.load_generators
      end

      def call(args)
        ARGV.replace args
        require "rails/commands/generate"
      end
    end
    Spring.register_command "generate", Generate.new, alias: "g"

    class Runner
      def call(args)
        Object.const_set(:APP_PATH, Rails.root.join('config/application'))
        ARGV.replace args
        require "rails/commands/runner"
      end
    end
    Spring.register_command "runner", Runner.new, alias: "r"
  end
end
