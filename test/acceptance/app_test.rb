require 'helper'
require 'io/wait'
require "timeout"
require "spring/sid"
require "spring/env"
require "pty"

class AppTest < ActiveSupport::TestCase
  def app_root
    Pathname.new("#{TEST_ROOT}/apps/rails-3-2")
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

    _, status = Timeout.timeout(opts.fetch(:timeout, 5)) { Process.wait2 }

    stdout, stderr = read_streams
    puts dump_streams(stdout, stderr) if ENV["SPRING_DEBUG"]

    @times << (Time.now - start_time) if @times

    {
      status: status,
      stdout: stdout,
      stderr: stderr,
    }
  rescue Timeout::Error => e
    raise e, "Output:\n\n#{dump_streams(*read_streams)}"
  end

  def read_streams
    [stdout, stderr].map(&:first).map do |stream|
      output = ""
      output << stream.readpartial(10240) while IO.select([stream], [], [], 0.1)
      output
    end
  end

  def dump_streams(stdout, stderr)
    output = "--- stdout ---\n"
    output << "#{stdout.chomp}\n"
    output << "--- stderr ---\n"
    output << "#{stderr.chomp}\n"
    output << "\n"
    output
  end

  def await_reload
    sleep 0.4
  end

  def assert_successful_run(*args)
    artifacts = app_run(*args)
    assert artifacts[:status].success?, "The run should be successful but it wasn't"
  end

  def assert_unsuccessful_run(*args)
    artifacts = app_run(*args)
    assert !artifacts[:status].success?, "The run should not be successful but it was"
  end

  %w(stdout stderr).each do |stream|
    class_eval <<-CODE, __FILE__, __LINE__ + 1
      def assert_#{stream}(command, expected)
        artifacts = app_run(command)
        assert artifacts[:#{stream}].include?(expected), \
               "expected '\#{expected}' to be in #{stream}. " \
                 "But it wasn't, the #{stream} was:\\n\#{artifacts[:#{stream}]}"
      end
    CODE
  end

  def assert_speedup(opts = {})
    ratio  = opts.fetch(:ratio, 0.6)
    from   = opts.fetch(:from, 0)
    first  = @times[from]
    second = @times[from + 1]

    assert (second / first) < ratio, "#{second} was not less than #{ratio} of #{first}"
  end

  def spring_test_command
    "#{spring} test #{@test}"
  end

  @@installed = false

  setup do
    @test                = "#{app_root}/test/functional/posts_controller_test.rb"
    @test_contents       = File.read(@test)
    @controller          = "#{app_root}/app/controllers/posts_controller.rb"
    @controller_contents = File.read(@controller)

    unless @@installed
      FileUtils.mkdir_p(gem_home)
      system "gem build spring.gemspec 2>/dev/null 1>/dev/null"
      app_run "gem install ../../../spring-#{Spring::VERSION}.gem"
      app_run "(gem list bundler | grep bundler) || gem install bundler #{'--pre' if RUBY_VERSION >= "2.0"}", timeout: nil
      app_run "bundle check || bundle update", timeout: nil
      app_run "bundle exec rake db:migrate db:test:clone"
      @@installed = true
    end

    FileUtils.rm_rf "#{app_root}/bin"
    @times = []
  end

  teardown do
    app_run "#{spring} stop"
    File.write(@test,       @test_contents)
    File.write(@controller, @controller_contents)
  end

  test "basic" do
    assert_stdout spring_test_command, "0 failures"
    assert_stdout spring_test_command, "0 failures"
    assert_speedup
  end

  test "help message when called without arguments" do
    assert_stdout spring, 'Usage: spring COMMAND [ARGS]'
  end

  test "test changes are picked up" do
    assert_stdout spring_test_command, "0 failures"

    File.write(@test, @test_contents.sub("get :index", "raise 'omg'"))
    assert_stdout spring_test_command, "RuntimeError: omg"

    assert_speedup
  end

  test "code changes are picked up" do
    assert_stdout spring_test_command, "0 failures"

    File.write(@controller, @controller_contents.sub("@posts = Post.all", "raise 'omg'"))
    assert_stdout spring_test_command, "RuntimeError: omg"

    assert_speedup
  end

  test "code changes in pre-referenced app files are picked up" do
    begin
      initializer = "#{app_root}/config/initializers/load_posts_controller.rb"
      File.write(initializer, "PostsController\n")

      assert_stdout spring_test_command, "0 failures"

      File.write(@controller, @controller_contents.sub("@posts = Post.all", "raise 'omg'"))
      assert_stdout spring_test_command, "RuntimeError: omg"

      assert_speedup
    ensure
      FileUtils.rm_f(initializer)
    end
  end

  test "app gets reloaded when preloaded files change" do
    begin
      application = "#{app_root}/config/application.rb"
      application_contents = File.read(application)

      assert_stdout spring_test_command, "0 failures"

      File.write(application, application_contents + <<-CODE)
        class Foo
          def self.omg
            raise "omg"
          end
        end
      CODE
      File.write(@test, @test_contents.sub("get :index", "Foo.omg"))

      await_reload

      assert_stdout spring_test_command, "RuntimeError: omg"
      assert_stdout spring_test_command, "RuntimeError: omg"

      assert_speedup from: 1
    ensure
      File.write(application, application_contents)
    end
  end

  test "app recovers when a boot-level error is introduced" do
    begin
      application = "#{app_root}/config/application.rb"
      application_contents = File.read(application)

      assert_stdout spring_test_command, "0 failures"

      File.write(application, application_contents + "\nomg")
      await_reload

      assert_unsuccessful_run spring_test_command

      File.write(application, application_contents)
      await_reload

      assert_stdout spring_test_command, "0 failures"
    ensure
      File.write(application, application_contents)
    end
  end

  test "stop command kills server" do
    app_run spring_test_command
    assert spring_env.server_running?, "The server should be running but it isn't"

    assert_successful_run "#{spring} stop"
    assert !spring_env.server_running?, "The server should not be running but it is"
  end

  test "custom commands" do
    assert_stdout "#{spring} custom", "omg"
  end

  test "runner alias" do
    assert_stdout "#{spring} r 'puts 1'", "1"
  end

  test "binstubs" do
    app_run "#{spring} binstub rake"
    assert_successful_run "bin/spring help"
    assert_stdout "bin/rake -T", "rake db:migrate"
  end

  test "after fork callback" do
    begin
      config_path = "#{app_root}/config/spring.rb"
      config_contents = File.read(config_path)

      File.write(config_path, config_contents + "\nSpring.after_fork { puts '!callback!' }")
      assert_stdout "spring r 'puts 2'", "!callback!\n2"
    ensure
      File.write(config_path, config_contents)
    end
  end

  test "missing config/application.rb" do
    begin
      FileUtils.mv app_root.join("config/application.rb"), app_root.join("config/application.rb.bak")
      assert_stderr "#{spring} rake -T", "unable to find your config/application.rb"
    ensure
      FileUtils.mv app_root.join("config/application.rb.bak"), app_root.join("config/application.rb")
    end
  end

  test "piping" do
    assert_stdout "#{spring} rake -T | grep db", "rake db:migrate"
  end
end
