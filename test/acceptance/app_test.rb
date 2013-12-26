# encoding: utf-8
require "helper"
require "acceptance/helper"
require "io/wait"
require "timeout"
require "spring/sid"

class AppTest < ActiveSupport::TestCase
  DEFAULT_SPEEDUP = 0.8

  def rails_version
    ENV['RAILS_VERSION'] || '~> 4.0.0'
  end

  def generator
    @@generator ||= Spring::Test::ApplicationGenerator.new(rails_version)
  end

  def app
    @app ||= Spring::Test::Application.new("#{TEST_ROOT}/apps/tmp")
  end

  def debug(artifacts)
    artifacts = artifacts.dup
    artifacts.delete :status
    app.dump_streams(artifacts.delete(:command), artifacts)
  end

  def assert_output(artifacts, expected)
    expected.each do |stream, output|
      assert artifacts[stream].include?(output),
             "expected #{stream} to include '#{output}'.\n\n#{debug(artifacts)}"
    end
  end

  def assert_success(command, expected_output = nil)
    artifacts = app.run(*Array(command))
    assert artifacts[:status].success?, "expected successful exit status\n\n#{debug(artifacts)}"
    assert_output artifacts, expected_output if expected_output
  end

  def assert_failure(command, expected_output = nil)
    artifacts = app.run(*Array(command))
    assert !artifacts[:status].success?, "expected unsuccessful exit status\n\n#{debug(artifacts)}"
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

  def assert_app_reloaded
    assert_success app.spring_test_command

    File.write(app.application_config.to_s, app.application_config.read + <<-CODE)
      class Foo
        def self.omg
          raise "omg"
        end
      end
    CODE
    File.write(app.test.to_s, app.test.read.sub("get :index", "Foo.omg"))

    app.await_reload
    assert_failure app.spring_test_command, stdout: "RuntimeError: omg"
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
    assert_success app.spring, stdout: 'Usage: spring COMMAND [ARGS]'
  end

  test "test changes are picked up" do
    assert_speedup do
      assert_success app.spring_test_command, stdout: "0 failures"

      File.write(app.test.to_s, app.test.read.sub("get :index", "raise 'omg'"))
      assert_failure app.spring_test_command, stdout: "RuntimeError: omg"
    end
  end

  test "code changes are picked up" do
    assert_speedup do
      assert_success app.spring_test_command, stdout: "0 failures"

      File.write(app.controller.to_s, app.controller.read.sub("@posts = Post.all", "raise 'omg'"))
      assert_failure app.spring_test_command, stdout: "RuntimeError: omg"
    end
  end

  test "code changes in pre-referenced app files are picked up" do
    File.write(app.path("config/initializers/load_posts_controller.rb").to_s, "PostsController\n")

    assert_speedup do
      assert_success app.spring_test_command, stdout: "0 failures"

      File.write(app.controller.to_s, app.controller.read.sub("@posts = Post.all", "raise 'omg'"))
      assert_failure app.spring_test_command, stdout: "RuntimeError: omg"
    end
  end

  test "app gets reloaded when preloaded files change (polling watcher)" do
    app.env["RAILS_ENV"] = "test"
    assert_success "#{app.spring} rails runner 'puts Spring.watcher.class'", stdout: "Polling"
    assert_app_reloaded
  end

  test "app gets reloaded when preloaded files change (listen watcher)" do
    File.write(app.gemfile.to_s, "#{app.gemfile.read}gem 'listen', '~> 1.0'")
    File.write(app.spring_config.to_s, "Spring.watch_method = :listen")
    app.bundle

    app.env["RAILS_ENV"] = "test"
    assert_success "#{app.spring} rails runner 'puts Spring.watcher.class'", stdout: "Listen"
    assert_app_reloaded
  end

  test "app recovers when a boot-level error is introduced" do
    config = app.application_config.read

    assert_success app.spring_test_command

    File.write(app.application_config.to_s, "#{config}\nomg")
    app.await_reload

    assert_failure app.spring_test_command

    File.write(app.application_config.to_s, config)
    assert_success app.spring_test_command
  end

  test "stop command kills server" do
    app.run app.spring_test_command
    assert app.spring_env.server_running?, "The server should be running but it isn't"

    assert_success "#{app.spring} stop"
    assert !app.spring_env.server_running?, "The server should not be running but it is"
  end

  test "custom commands" do
    File.write(app.spring_config.to_s, <<-CODE)
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

    assert_success "#{app.spring} custom", stdout: "omg"

    assert_success "#{app.spring} binstub custom"
    assert_success "bin/custom", stdout: "omg"

    app.env["DISABLE_SPRING"] = "1"
    assert_success %{bin/custom -e 'puts "foo"'}, stdout: "foo"
  end

  test "binstub" do
    assert_success "#{app.spring} binstub rake rails", stdout: "spring inserted"
    assert_success "bin/rake -T", stdout: "rake db:migrate"
    assert_success "bin/rails runner 'puts %(omg)'", stdout: "omg"
    assert_success "bin/rails server --help", stdout: "Usage: rails server"
    assert_success "bin/spring status", stdout: "Spring is running"

    assert_success "#{app.spring} binstub rake", stdout: "bin/rake: spring already present"
  end

  test "binstub --all" do
    assert_success "#{app.spring} binstub --all"
    assert_success "bin/rake -T", stdout: "rake db:migrate"
    assert_success "bin/rails runner 'puts %(omg)'", stdout: "omg"
  end

  test "after fork callback" do
    File.write(app.spring_config.to_s, "Spring.after_fork { puts '!callback!' }")
    assert_success "#{app.spring} rails runner 'puts 2'", stdout: "!callback!\n2"
  end

  test "global config file evaluated" do
    File.write("#{app.user_home}/.spring.rb", "Spring.after_fork { puts '!callback!' }")
    assert_success "#{app.spring} rails runner 'puts 2'", stdout: "!callback!\n2"
  end

  test "missing config/application.rb" do
    app.application_config.delete
    assert_failure "#{app.spring} rake -T", stderr: "unable to find your config/application.rb"
  end

  test "piping" do
    assert_success "#{app.spring} rake -T | grep db", stdout: "rake db:migrate"
  end

  test "status" do
    assert_success "#{app.spring} status", stdout: "Spring is not running"
    assert_success "#{app.spring} rails runner ''"
    assert_success "#{app.spring} status", stdout: "Spring is running"
  end

  test "runner command sets Rails environment from command-line options" do
    assert_success "#{app.spring} rails runner -e production 'puts Rails.env'", stdout: "production"
    assert_success "#{app.spring} rails runner --environment=production 'puts Rails.env'", stdout: "production"
  end

  test "forcing rails env via environment variable" do
    app.env['RAILS_ENV'] = 'production'
    assert_success "#{app.spring} rake -p 'Rails.env'", stdout: "production"
  end

  test "setting env vars with rake" do
    File.write(app.path("lib/tasks/env.rake").to_s, <<-'CODE')
      task :print_rails_env => :environment do
        puts Rails.env
      end

      task :print_env do
        ENV.each { |k, v| puts "#{k}=#{v}" }
      end

      task(:default).clear.enhance [:print_rails_env]
    CODE

    assert_success "#{app.spring} rake RAILS_ENV=test print_rails_env", stdout: "test"
    assert_success "#{app.spring} rake FOO=bar print_env", stdout: "FOO=bar"
    assert_success "#{app.spring} rake", stdout: "test"
  end

  test "changing the Gemfile restarts the server" do
    assert_success %(#{app.spring} rails runner 'require "sqlite3"')

    File.write(app.gemfile.to_s, app.gemfile.read.sub(%{gem 'sqlite3'}, %{# gem 'sqlite3'}))
    app.bundle

    app.await_reload
    assert_failure %(#{app.spring} rails runner 'require "sqlite3"'), stderr: "sqlite3"
  end

  test "changing the environment between runs" do
    File.write(app.application_config.to_s, "#{app.application_config.read}\nENV['BAR'] = 'bar'")

    app.env["OMG"] = "1"
    app.env["FOO"] = "1"
    app.env["RUBYOPT"] = "-rubygems"

    assert_success %(#{app.spring} rails runner 'p ENV["OMG"]'), stdout: "1"
    assert_success %(#{app.spring} rails runner 'p ENV["BAR"]'), stdout: "bar"
    assert_success %(#{app.spring} rails runner 'p ENV.key?("BUNDLE_GEMFILE")'), stdout: "true"
    assert_success %(#{app.spring} rails runner 'p ENV["RUBYOPT"]'), stdout: "bundler"

    app.env["OMG"] = "2"
    app.env.delete "FOO"

    assert_success %(#{app.spring} rails runner 'p ENV["OMG"]'), stdout: "2"
    assert_success %(#{app.spring} rails runner 'p ENV.key?("FOO")'), stdout: "false"
  end
end
