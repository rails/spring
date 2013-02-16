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

  def server_pidfile
    "#{app_root}/tmp/spring/#{Spring::SID.sid}.pid"
  end

  def spring_env
    @spring_env ||= Spring::Env.new(app_root)
  end

  def server_pid
    spring_env.pid
  end

  def server_running?
    spring_env.server_running?
  end

  def pty
    @pty ||= PTY.open
  end

  def output
    pty.first
  end

  def app_run(command, opts = {})
    start_time = Time.now

    Bundler.with_clean_env do
      Process.spawn(
        { "GEM_HOME" => gem_home.to_s, "GEM_PATH" => "" },
        command.to_s,
        out:   pty.last,
        err:   pty.last,
        in:    pty.last,
        chdir: app_root.to_s,
      )
    end

    _, status = Timeout.timeout(opts.fetch(:timeout, 10)) { Process.wait2 }

    output = read_output
    puts output if ENV["SPRING_DEBUG"]

    @times << (Time.now - start_time) if @times

    [status, output]
  rescue Timeout::Error
    raise "timed out. output was:\n\n#{read_output}"
  end

  def read_output
    output.ready? ? output.readpartial(10240) : ""
  end

  def await_reload
    sleep 0.4
  end

  def assert_successful_run(*args)
    status, _ = app_run(*args)
    assert status.success?, "The run should be successful but it wasn't"
  end

  def assert_unsuccessful_run(*args)
    status, _ = app_run(*args)
    assert !status.success?, "The run should not be successful but it was"
  end

  def assert_output(command, expected)
    _, output = app_run(command)
    assert output.include?(expected), "expected '#{expected}' to be output. But it wasn't, the output is:\n#{output}"
  end

  def assert_speedup(opts = {})
    ratio  = opts.fetch(:ratio, 0.5)
    from   = opts.fetch(:from, 0)
    first  = @times[from]
    second = @times[from + 1]

    assert (second / first) < ratio, "#{second} was not less than #{ratio} of #{first}"
  end

  def assert_server_running(*args)
    assert server_running?, "The server should be running but it isn't"
  end

  def assert_server_not_running(*args)
    assert !server_running?, "The server should not be running but it is"
  end

  def test_command
    "#{spring} test #{@test}"
  end

  @@installed = false

  setup do
    @test                = "#{app_root}/test/functional/posts_controller_test.rb"
    @test_contents       = File.read(@test)
    @controller          = "#{app_root}/app/controllers/posts_controller.rb"
    @controller_contents = File.read(@controller)
    @spring_env          = Spring::Env.new(app_root)

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
    if pid = server_pid
      Process.kill('TERM', pid)
    end

    File.write(@test,       @test_contents)
    File.write(@controller, @controller_contents)
  end

  test "basic" do
    assert_output test_command, "0 failures"
    assert File.exist?(server_pidfile)

    assert_output test_command, "0 failures"
    assert_speedup
  end

  test "help message when called without arguments" do
    assert_output spring, 'Usage: spring COMMAND [ARGS]'
  end

  test "test changes are picked up" do
    assert_output test_command, "0 failures"

    File.write(@test, @test_contents.sub("get :index", "raise 'omg'"))
    assert_output test_command, "RuntimeError: omg"

    assert_speedup
  end

  test "code changes are picked up" do
    assert_output test_command, "0 failures"

    File.write(@controller, @controller_contents.sub("@posts = Post.all", "raise 'omg'"))
    assert_output test_command, "RuntimeError: omg"

    assert_speedup
  end

  test "code changes in pre-referenced app files are picked up" do
    begin
      initializer = "#{app_root}/config/initializers/load_posts_controller.rb"
      File.write(initializer, "PostsController\n")

      assert_output test_command, "0 failures"

      File.write(@controller, @controller_contents.sub("@posts = Post.all", "raise 'omg'"))
      assert_output test_command, "RuntimeError: omg"

      assert_speedup
    ensure
      FileUtils.rm_f(initializer)
    end
  end

  test "app gets reloaded when preloaded files change" do
    begin
      application = "#{app_root}/config/application.rb"
      application_contents = File.read(application)

      assert_output test_command, "0 failures"

      File.write(application, application_contents + <<-CODE)
        class Foo
          def self.omg
            raise "omg"
          end
        end
      CODE
      File.write(@test, @test_contents.sub("get :index", "Foo.omg"))

      await_reload

      assert_output test_command, "RuntimeError: omg"
      assert_output test_command, "RuntimeError: omg"

      assert_speedup from: 1
    ensure
      File.write(application, application_contents)
    end
  end

  test "app recovers when a boot-level error is introduced" do
    begin
      application = "#{app_root}/config/application.rb"
      application_contents = File.read(application)

      assert_output test_command, "0 failures"

      File.write(application, application_contents + "\nomg")
      await_reload

      assert_unsuccessful_run test_command

      File.write(application, application_contents)
      await_reload

      assert_output test_command, "0 failures"
    ensure
      File.write(application, application_contents)
    end
  end

  test "stop command kills server" do
    app_run test_command
    assert_server_running

    assert_successful_run "#{spring} stop"
    assert_server_not_running
  end

  test "custom commands" do
    assert_output "#{spring} custom", "omg"
  end

  test "runner alias" do
    assert_output "#{spring} r 'puts 1'", "1"
  end

  test "binstubs" do
    app_run "#{spring} binstub rake"
    assert_successful_run "bin/spring help"
    assert_output "bin/rake -T", "rake db:migrate"
  end

  test "missing config/application.rb" do
    begin
      FileUtils.mv app_root.join("config/application.rb"), app_root.join("config/application.rb.bak")
      assert_output "#{spring} rake -T", "unable to find your config/application.rb"
    ensure
      FileUtils.mv app_root.join("config/application.rb.bak"), app_root.join("config/application.rb")
    end
  end

  test "piping" do
    assert_output "#{spring} rake -T | grep db", "rake db:migrate"
  end
end
