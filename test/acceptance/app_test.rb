require 'helper'
require 'io/wait'
require "timeout"
require "spring/sid"
require "spring/env"

class AppTest < ActiveSupport::TestCase
  def app_root
    Pathname.new("#{TEST_ROOT}/apps/rails-3-2")
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
        {
          "GEM_HOME" => "#{app_root}/vendor/gems",
          "GEM_PATH" => "",
          "PATH"     => "#{app_root}/vendor/gems/bin:#{ENV["PATH"]}"
        },
        command,
        out:   stdout.last,
        err:   stderr.last,
        chdir: app_root.to_s,
      )
    end

    _, status = Timeout.timeout(opts.fetch(:timeout, 5)) { Process.wait2 }

    out, err = read_streams

    @times << (Time.now - start_time) if @times

    print_streams(out, err) if ENV["SPRING_DEBUG"]

    [status, out, err]
  rescue Timeout::Error
    print_streams *read_streams
    raise
  end

  def print_streams(out, err)
    puts "---"
    puts out
    puts "***"
    puts err
    puts "---"
  end

  def read_streams
    [stdout, stderr].map(&:first).map { |s| s.ready? ? s.readpartial(10240) : "" }
  end

  def await_reload
    sleep 0.4
  end

  def assert_successful_run(*args)
    status, _, _ = app_run(*args)
    assert status.success?, "The run should be successful but it wasn't"
  end

  def assert_unsuccessful_run(*args)
    status, _, _ = app_run(*args)
    assert !status.success?, "The run should not be successful but it was"
  end

  def assert_stdout(command, expected)
    _, stdout, _ = app_run(command)
    assert stdout.include?(expected), "expected '#{expected}' to be printed to stdout. But it wasn't, the stdout is:\n#{stdout}"
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
    "spring test #{@test}"
  end

  @@installed_spring = false

  setup do
    @test                = "#{app_root}/test/functional/posts_controller_test.rb"
    @test_contents       = File.read(@test)
    @controller          = "#{app_root}/app/controllers/posts_controller.rb"
    @controller_contents = File.read(@controller)

    @spring_env          = Spring::Env.new(app_root)

    unless @@installed_spring
      system "gem build spring.gemspec 2>/dev/null 1>/dev/null"
      app_run "gem install ../../../spring-*.gem"
      @@installed_spring = true
    end

    FileUtils.rm_rf "#{app_root}/bin"
    app_run "(gem list bundler | grep bundler) || gem install bundler", timeout: nil
    app_run "bundle check || bundle update", timeout: nil
    app_run "bundle exec rake db:migrate"

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
    assert_successful_run test_command
    assert File.exist?(server_pidfile)

    assert_successful_run test_command
    assert_speedup
  end

  test "help message when called without arguments" do
    assert_stdout "spring", 'Usage: spring COMMAND [ARGS]'
  end

  test "test changes are picked up" do
    assert_successful_run test_command

    File.write(@test, @test_contents.sub("get :index", "raise 'omg'"))
    assert_stdout test_command, "RuntimeError: omg"

    assert_speedup
  end

  test "code changes are picked up" do
    assert_successful_run test_command

    File.write(@controller, @controller_contents.sub("@posts = Post.all", "raise 'omg'"))
    assert_stdout test_command, "RuntimeError: omg"

    assert_speedup
  end

  test "code changes in pre-referenced app files are picked up" do
    begin
      initializer = "#{app_root}/config/initializers/load_posts_controller.rb"
      File.write(initializer, "PostsController\n")

      assert_successful_run test_command

      File.write(@controller, @controller_contents.sub("@posts = Post.all", "raise 'omg'"))
      assert_stdout test_command, "RuntimeError: omg"

      assert_speedup
    ensure
      FileUtils.rm_f(initializer)
    end
  end

  test "app gets reloaded when preloaded files change" do
    begin
      application = "#{app_root}/config/application.rb"
      application_contents = File.read(application)

      assert_successful_run test_command

      File.write(application, application_contents + <<-CODE)
        class Foo
          def self.omg
            raise "omg"
          end
        end
      CODE
      File.write(@test, @test_contents.sub("get :index", "Foo.omg"))

      await_reload

      assert_stdout test_command, "RuntimeError: omg"
      assert_stdout test_command, "RuntimeError: omg"

      assert_speedup from: 1
    ensure
      File.write(application, application_contents)
    end
  end

  test "app recovers when a boot-level error is introduced" do
    begin
      application = "#{app_root}/config/application.rb"
      application_contents = File.read(application)

      assert_successful_run test_command

      File.write(application, application_contents + "\nomg")
      await_reload

      assert_unsuccessful_run test_command

      File.write(application, application_contents)
      await_reload

      assert_successful_run test_command
    ensure
      File.write(application, application_contents)
    end
  end

  test "stop command kills server" do
    assert_successful_run test_command
    assert_server_running

    assert_successful_run 'spring stop'
    assert_server_not_running
  end

  test "custom commands" do
    assert_stdout "spring custom", "omg"
  end

  test "runner alias" do
    assert_stdout "spring r 'puts 1'", "1"
  end

  test "binstubs" do
    app_run "spring binstub rake"
    assert_successful_run "bin/spring help"
    assert_stdout "bin/rake -T", "rake db:migrate"
  end
end
