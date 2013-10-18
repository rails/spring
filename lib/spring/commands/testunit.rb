module Spring
  module Commands
    class TestUnit
      def env(*)
        "test"
      end

      def call
        $LOAD_PATH.unshift "test"
        ARGV << "test" if ARGV.empty?
        ARGV.each do |arg|
          break if arg.start_with?("-")
          require_test(File.expand_path(arg))
        end
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

      def fallback
        %{exec "bundle", "exec", "ruby", "-Itest", *ARGV}
      end
    end

    Spring.register_command "testunit", TestUnit.new
  end
end
