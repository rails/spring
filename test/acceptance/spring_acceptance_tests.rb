require 'helper'
require 'io/wait'
require "timeout"
require "spring/sid"
require "spring/env"
require "pty"

module SpringAcceptanceTests

  module ClassMethods
    attr_accessor :installed
  end

  def self.included(base)
    base.extend ClassMethods
  end

  def gem_home
    app_root.join "vendor/gems/#{RUBY_VERSION}"
  end

  def spring
    gem_home.join "bin/spring"
  end

  def spring_env
    @spring_env ||= Spring::Env.new(app_root)
  end

  def stdout
    @stdout ||= IO.pipe
  end

  def stderr
    @stderr ||= IO.pipe
  end

  def app_run(command, opts = {})
    start_time = Time.now

    Bundler.with_clean_env do
      Process.spawn(
        { "GEM_HOME" => gem_home.to_s, "GEM_PATH" => "" },
        command.to_s,
        out:   stdout.last,
        err:   stderr.last,
        in:    :close,
        chdir: app_root.to_s,
      )
    end

    _, status = Timeout.timeout(opts.fetch(:timeout, 10)) { Process.wait2 }

    stdout, stderr = read_streams
    puts dump_streams(command, stdout, stderr) if ENV["SPRING_DEBUG"]

    @times << (Time.now - start_time) if @times

    {
      status: status,
      stdout: stdout,
      stderr: stderr,
    }
  rescue Timeout::Error => e
    raise e, "Output:\n\n#{dump_streams(command, *read_streams)}"
  end

  def read_streams
    [stdout, stderr].map(&:first).map do |stream|
      output = ""
      output << stream.readpartial(10240) while IO.select([stream], [], [], 0.1)
      output
    end
  end

  def dump_streams(command, stdout, stderr)
    output = "$ #{command}\n"

    unless stdout.chomp.empty?
      output << "--- stdout ---\n"
      output << "#{stdout.chomp}\n"
    end

    unless stderr.chomp.empty?
      output << "--- stderr ---\n"
      output << "#{stderr.chomp}\n"
    end

    output << "\n"
    output
  end

  def await_reload
    sleep 0.4
  end

  def assert_output(artifacts, expected)
    expected.each do |stream, output|
      assert artifacts[stream].include?(output),
             "expected #{stream} to include '#{output}', but it was:\n\n#{artifacts[stream]}"
    end
  end

  def assert_success(command, expected_output = nil)
    artifacts = app_run(command)
    assert artifacts[:status].success?, "expected successful exit status"
    assert_output artifacts, expected_output if expected_output
  end

  def assert_failure(command, expected_output = nil)
    artifacts = app_run(command)
    assert !artifacts[:status].success?, "expected unsuccessful exit status"
    assert_output artifacts, expected_output if expected_output
  end

  def assert_speedup(ratio = 0.6)
    @times = []
    yield
    assert (@times.last / @times.first) < ratio, "#{@times.last} was not less than #{ratio} of #{@times.first}"
    @times = nil
  end

  def spring_test_command
    "#{spring} test #{@test}"
  end


  def controller_test_path
    "#{app_root}/test/functional/posts_controller_test.rb"
  end

  def setup
    @test                = controller_test_path
    @test_contents       = File.read(@test)
    @controller          = "#{app_root}/app/controllers/posts_controller.rb"
    @controller_contents = File.read(@controller)

    unless self.class.installed
      FileUtils.mkdir_p(gem_home)
      system "gem build spring.gemspec 2>/dev/null 1>/dev/null"
      app_run "gem install ../../../spring-#{Spring::VERSION}.gem"
      app_run "(gem list bundler | grep bundler) || gem install bundler #{'--pre' if RUBY_VERSION >= "2.0"}", timeout: nil
      app_run "bundle check || bundle update", timeout: nil
      app_run "bundle exec rake db:migrate db:test:clone"
      self.class.installed = true
    end

    FileUtils.rm_rf "#{app_root}/bin"
  end

  def teardown
    app_run "#{spring} stop"
    File.write(@test,       @test_contents)
    File.write(@controller, @controller_contents)
  end

  def test_basic
    assert_speedup do
      2.times { app_run spring_test_command }
    end
  end

  def test_help_message_when_called_without_arguments
    assert_success spring, stdout: 'Usage: spring COMMAND [ARGS]'
  end

  def test_changes_are_picked_up
    assert_speedup do
      assert_success spring_test_command, stdout: "0 failures, 0 errors"

      File.write(@test, @test_contents.sub("get :index", "raise 'omg'"))
      assert_failure spring_test_command, stdout: "RuntimeError: omg"
    end
  end

  def test_code_changes_are_picked_up
    assert_speedup do
      assert_success spring_test_command, stdout: "0 failures, 0 errors"

      File.write(@controller, @controller_contents.sub("@posts = Post.all", "raise 'omg'"))
      assert_failure spring_test_command, stdout: "RuntimeError: omg"
    end
  end

  def test_code_changes_in_pre_referenced_app_files_are_picked_up
    begin
      initializer = "#{app_root}/config/initializers/load_posts_controller.rb"
      File.write(initializer, "PostsController\n")

      assert_speedup do
        assert_success spring_test_command, stdout: "0 failures, 0 errors"

        File.write(@controller, @controller_contents.sub("@posts = Post.all", "raise 'omg'"))
        assert_failure spring_test_command, stdout: "RuntimeError: omg"
      end
    ensure
      FileUtils.rm_f(initializer)
    end
  end

  def assert_app_reloaded
    application = "#{app_root}/config/application.rb"
    application_contents = File.read(application)

    assert_success spring_test_command

    File.write(application, application_contents + <<-CODE)
      class Foo
        def self.omg
          raise "omg"
        end
      end
    CODE
    File.write(@test, @test_contents.sub("get :index", "Foo.omg"))

    await_reload

    assert_speedup do
      2.times { assert_failure spring_test_command, stdout: "RuntimeError: omg" }
    end
  ensure
    File.write(application, application_contents)
  end

  def test_app_gets_reloaded_when_preloaded_files_change_polling_watcher
    assert_success "#{spring} runner 'puts Spring.watcher.class'", stdout: "Polling"
    assert_app_reloaded
  end

  def test_app_gets_reloaded_when_preloaded_files_change_listen_watcher
    # listen with ruby 2.0.0-rc1 crashes on travis, revisit when they install 2.0.0-p0
    skip if RUBY_VERSION == "2.0.0" && RUBY_PATCHLEVEL == -1

    begin
      gemfile = app_root.join("Gemfile")
      gemfile_contents = gemfile.read
      File.write(gemfile, gemfile_contents.sub(%{# gem 'listen'}, %{gem 'listen'}))
      app_run "bundle install", timeout: nil

      assert_success "#{spring} runner 'puts Spring.watcher.class'", stdout: "Listen"
      assert_app_reloaded
    ensure
      File.write(gemfile, gemfile_contents)
      assert_success "bundle check"
    end
  end

  def test_app_recovers_when_a_boot_level_error_is_introduced
    begin
      application = "#{app_root}/config/application.rb"
      application_contents = File.read(application)

      assert_success spring_test_command

      File.write(application, application_contents + "\nomg")
      await_reload

      assert_failure spring_test_command

      File.write(application, application_contents)
      await_reload

      assert_success spring_test_command
    ensure
      File.write(application, application_contents)
    end
  end

  def test_stop_command_kills_server
    app_run spring_test_command
    assert spring_env.server_running?, "The server should be running but it isn't"

    assert_success "#{spring} stop"
    assert !spring_env.server_running?, "The server should not be running but it is"
  end

  def test_custom_commands
    assert_success "#{spring} custom", stdout: "omg"
  end

  def test_runner_alias
    assert_success "#{spring} r 'puts 1'", stdout: "1"
  end

  def test_binstubs
    app_run "#{spring} binstub rake"
    assert_success "bin/spring help"
    assert_success "bin/rake -T", stdout: "rake db:migrate"
  end

  def test_after_fork_callback
    begin
      config_path = "#{app_root}/config/spring.rb"
      config_contents = File.read(config_path)

      File.write(config_path, config_contents + "\nSpring.after_fork { puts '!callback!' }")
      assert_success "#{spring} r 'puts 2'", stdout: "!callback!\n2"
    ensure
      File.write(config_path, config_contents)
    end
  end

  def test_missing_config_application
    begin
      FileUtils.mv app_root.join("config/application.rb"), app_root.join("config/application.rb.bak")
      assert_failure "#{spring} rake -T", stderr: "unable to find your config/application.rb"
    ensure
      FileUtils.mv app_root.join("config/application.rb.bak"), app_root.join("config/application.rb")
    end
  end

  def test_piping
    assert_success "#{spring} rake -T | grep db", stdout: "rake db:migrate"
  end

  def test_status
    assert_success "#{spring} status", stdout: "Spring is not running"
    app_run "#{spring} runner ''"
    assert_success "#{spring} status", stdout: "Spring is running"
  end

  def test_runner_command_sets_rails_environment_from_command_line_options
    # Not using "test" environment here to avoid false positives on Travis (where "test" is default)
    assert_success "#{spring} runner -e development 'puts Rails.env'", stdout: "development"
    assert_success "#{spring} runner --environment=development 'puts Rails.env'", stdout: "development"
  end
end


