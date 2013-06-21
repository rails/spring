module Spring
  module Commands
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
  end
end
