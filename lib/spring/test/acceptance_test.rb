# encoding: utf-8

require "io/wait"
require "timeout"
require "spring/sid"
require "spring/client"

module Spring
  module Test
    class AcceptanceTest < ActiveSupport::TestCase
      runnables.delete self # prevent Minitest running this class

      DEFAULT_SPEEDUP = 0.8

      def rails_version
        ENV['RAILS_VERSION'] || '~> 4.2.0'
      end

      # Extension point for spring-watchers-listen
      def generator_klass
        Spring::Test::ApplicationGenerator
      end

      def generator
        @@generator ||= generator_klass.new(rails_version)
      end

      def app
        @app ||= Spring::Test::Application.new("#{Spring::Test.root}/apps/tmp")
      end

      def assert_output(artifacts, expected)
        expected.each do |stream, output|
          assert artifacts[stream].include?(output),
                 "expected #{stream} to include '#{output}'.\n\n#{app.debug(artifacts)}"
        end
      end

      def assert_success(command, expected_output = nil)
        artifacts = app.run(*Array(command))
        assert artifacts[:status].success?, "expected successful exit status\n\n#{app.debug(artifacts)}"
        assert_output artifacts, expected_output if expected_output
      end

      def assert_failure(command, expected_output = nil)
        artifacts = app.run(*Array(command))
        assert !artifacts[:status].success?, "expected unsuccessful exit status\n\n#{app.debug(artifacts)}"
        assert_output artifacts, expected_output if expected_output
      end

      def assert_speedup(ratio = DEFAULT_SPEEDUP)
        if ENV['CI']
          yield
        else
          app.with_timing do
            yield
            assert app.timing_ratio < ratio, "#{app.last_time} was not less than #{ratio} of #{app.first_time}"
          end
        end
      end

      setup do
        generator.generate_if_missing
        generator.install_spring
        generator.copy_to(app.root)
      end

      teardown do
        app.stop_spring
      end

      test "basic" do
        assert_speedup do
          2.times { app.run app.spring_test_command }
        end
      end

      test "help message when called without arguments" do
        assert_success "bin/spring", stdout: 'Usage: spring COMMAND [ARGS]'
      end

      test "test changes are picked up" do
        assert_speedup do
          assert_success app.spring_test_command, stdout: "0 failures"

          File.write(app.test, app.test.read.sub("get :index", "raise 'omg'"))
          assert_failure app.spring_test_command, stdout: "RuntimeError: omg"
        end
      end

      test "code changes are picked up" do
        assert_speedup do
          assert_success app.spring_test_command, stdout: "0 failures"

          File.write(app.controller, app.controller.read.sub("@posts = Post.all", "raise 'omg'"))
          assert_failure app.spring_test_command, stdout: "RuntimeError: omg"
        end
      end

      test "code changes in pre-referenced app files are picked up" do
        File.write(app.path("config/initializers/load_posts_controller.rb"), "PostsController\n")

        assert_speedup do
          assert_success app.spring_test_command, stdout: "0 failures"

          File.write(app.controller, app.controller.read.sub("@posts = Post.all", "raise 'omg'"))
          assert_failure app.spring_test_command, stdout: "RuntimeError: omg"
        end
      end

      test "app gets reloaded when preloaded files change" do
        assert_success app.spring_test_command

        File.write(app.application_config, app.application_config.read + <<-CODE)
          class Foo
            def self.omg
              raise "omg"
            end
          end
        CODE
        File.write(app.test, app.test.read.sub("get :index", "Foo.omg"))

        app.await_reload
        assert_failure app.spring_test_command, stdout: "RuntimeError: omg"
      end

      test "app gets reloaded even with a ton of boot output" do
        limit = UNIXSocket.pair.first.getsockopt(:SOCKET, :SNDBUF).int

        assert_success app.spring_test_command
        File.write(app.path("config/initializers/verbose.rb"), "#{limit}.times { puts 'x' }")

        app.await_reload
        assert_success app.spring_test_command
      end

      test "app recovers when a boot-level error is introduced" do
        config = app.application_config.read

        assert_success app.spring_test_command

        File.write(app.application_config, "#{config}\nomg")
        app.await_reload

        assert_failure app.spring_test_command

        File.write(app.application_config, config)
        assert_success app.spring_test_command
      end

      test "stop command kills server" do
        app.run app.spring_test_command
        assert app.spring_env.server_running?, "The server should be running but it isn't"

        assert_success "bin/spring stop"
        assert !app.spring_env.server_running?, "The server should not be running but it is"
      end

      test "custom commands" do
        # Start spring before setting up the command, to test that it gracefully upgrades itself
        assert_success "bin/rails runner ''"

        File.write(app.spring_config, <<-CODE)
          class CustomCommand
            def call
              puts "omg"
            end

            def exec_name
              "rake"
            end
          end

          Spring.register_command "custom", CustomCommand.new
        CODE

        assert_success "bin/spring custom", stdout: "omg"

        assert_success "bin/spring binstub custom"
        assert_success "bin/custom", stdout: "omg"

        app.env["DISABLE_SPRING"] = "1"
        assert_success %{bin/custom -e 'puts "foo"'}, stdout: "foo"
      end

      test "binstub" do
        assert_success "bin/rails server --help", stdout: "Usage: rails server" # rails command fallback

        assert_success "#{app.spring} binstub rake", stdout: "bin/rake: spring already present"

        assert_success "#{app.spring} binstub --remove rake", stdout: "bin/rake: spring removed"
        assert !app.path("bin/rake").read.include?(Spring::Client::Binstub::LOADER)
        assert_success "bin/rake -T", stdout: "rake db:migrate"
      end

      test "binstub when spring is uninstalled" do
        app.run! "gem uninstall --ignore-dependencies spring"
        File.write(app.gemfile, app.gemfile.read.gsub(/gem 'spring.*/, ""))
        assert_success "bin/rake -T", stdout: "rake db:migrate"
      end

      test "binstub upgrade" do
        File.write(app.path("bin/rake"), <<CODE)
#!/usr/bin/env ruby

if !Process.respond_to?(:fork) || Gem::Specification.find_all_by_name("spring").empty?
  exec "bundle", "exec", "rake", *ARGV
else
  ARGV.unshift "rake"
  load Gem.bin_path("spring", "spring")
end
CODE

        File.write(app.path("bin/rails"), <<CODE)
#!/usr/bin/env ruby

if !Process.respond_to?(:fork) || Gem::Specification.find_all_by_name("spring").empty?
  APP_PATH = File.expand_path('../../config/application',  __FILE__)
  require_relative '../config/boot'
  require 'rails/commands'
else
  ARGV.unshift "rails"
  load Gem.bin_path("spring", "spring")
end
CODE

        assert_success "bin/spring binstub --all", stdout: "upgraded"

        assert_equal app.path("bin/rake").read, <<CODE
#!/usr/bin/env ruby
#{Spring::Client::Binstub::LOADER.strip}
require 'bundler/setup'
load Gem.bin_path('rake', 'rake')
CODE

    assert_equal app.path("bin/rails").read, <<CODE
#!/usr/bin/env ruby
#{Spring::Client::Binstub::LOADER.strip}
APP_PATH = File.expand_path('../../config/application',  __FILE__)
require_relative '../config/boot'
require 'rails/commands'
CODE
      end

      test "after fork callback" do
        File.write(app.spring_config, "Spring.after_fork { puts '!callback!' }")
        assert_success "bin/rails runner 'puts 2'", stdout: "!callback!\n2"
      end

      test "global config file evaluated" do
        File.write("#{app.user_home}/.spring.rb", "Spring.after_fork { puts '!callback!' }")
        assert_success "bin/rails runner 'puts 2'", stdout: "!callback!\n2"
      end

      test "missing config/application.rb" do
        app.application_config.delete
        assert_failure "bin/rake -T", stderr: "unable to find your config/application.rb"
      end

      test "piping" do
        assert_success "bin/rake -T | grep db", stdout: "rake db:migrate"
      end

      test "status" do
        assert_success "bin/spring status", stdout: "Spring is not running"
        assert_success "bin/rails runner ''"
        assert_success "bin/spring status", stdout: "Spring is running"
      end

      test "runner command sets Rails environment from command-line options" do
        assert_success "bin/rails runner -e test 'puts Rails.env'", stdout: "test"
        assert_success "bin/rails runner --environment=test 'puts Rails.env'", stdout: "test"
      end

      test "forcing rails env via environment variable" do
        app.env['RAILS_ENV'] = 'test'
        assert_success "bin/rake -p 'Rails.env'", stdout: "test"
      end

      test "setting env vars with rake" do
        File.write(app.path("lib/tasks/env.rake"), <<-'CODE')
          task :print_rails_env => :environment do
            puts Rails.env
          end

          task :print_env do
            ENV.each { |k, v| puts "#{k}=#{v}" }
          end

          task(:default).clear.enhance [:print_rails_env]
        CODE

        assert_success "bin/rake RAILS_ENV=test print_rails_env", stdout: "test"
        assert_success "bin/rake FOO=bar print_env", stdout: "FOO=bar"
        assert_success "bin/rake", stdout: "test"
      end

      test "changing the Gemfile works" do
        assert_success %(bin/rails runner 'require "sqlite3"')

        File.write(app.gemfile, app.gemfile.read.sub(%{gem 'sqlite3'}, %{# gem 'sqlite3'}))
        app.await_reload

        assert_failure %(bin/rails runner 'require "sqlite3"'), stderr: "sqlite3"
      end

      test "changing the Gemfile works when spring calls into itself" do
        File.write(app.path("script.rb"), <<-CODE)
          gemfile = Rails.root.join("Gemfile")
          File.write(gemfile, "\#{gemfile.read}gem 'devise'\\n")
          Bundler.with_clean_env do
            system(#{app.env.inspect}, "bundle install")
          end
          output = `\#{Rails.root.join('bin/rails')} runner 'require "devise"; puts "done";'`
          exit output == "done\n"
        CODE

        assert_success [%(bin/rails runner 'load Rails.root.join("script.rb")'), timeout: 60]
      end

      test "changing the environment between runs" do
        File.write(app.application_config, "#{app.application_config.read}\nENV['BAR'] = 'bar'")

        app.env["OMG"] = "1"
        app.env["FOO"] = "1"
        app.env["RUBYOPT"] = "-rubygems"

        assert_success %(bin/rails runner 'p ENV["OMG"]'), stdout: "1"
        assert_success %(bin/rails runner 'p ENV["BAR"]'), stdout: "bar"
        assert_success %(bin/rails runner 'p ENV.key?("BUNDLE_GEMFILE")'), stdout: "true"
        assert_success %(bin/rails runner 'p ENV["RUBYOPT"]'), stdout: "bundler"

        app.env["OMG"] = "2"
        app.env.delete "FOO"

        assert_success %(bin/rails runner 'p ENV["OMG"]'), stdout: "2"
        assert_success %(bin/rails runner 'p ENV.key?("FOO")'), stdout: "false"
      end

      test "Kernel.raise remains private" do
        expr = "p Kernel.private_instance_methods.include?(:raise)"
        assert_success %(bin/rails runner '#{expr}'), stdout: "true"
      end
    end
  end
end
