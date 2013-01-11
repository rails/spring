require 'helper'
require 'io/wait'
require "timeout"

class AppTest < ActiveSupport::TestCase
  BINFILE = File.expand_path('../bin/spring', TEST_ROOT)

  def app_root
    "#{TEST_ROOT}/apps/rails-3-2"
  end

  def server_pidfile
    "#{app_root}/tmp/spring/#{Spring::SID.sid}.pid"
  end

  def server_pid
    File.exist?(server_pidfile) ? File.read(server_pidfile).to_i : nil
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
        command,
        out:   stdout.last,
        err:   stderr.last,
        chdir: app_root,
      )
    end

    _, status = Timeout.timeout(5) { Process.wait2 }

    out, err = read_streams

    @times << (Time.now - start_time) if opts.fetch(:timer, true)

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
    sleep 0.2
  end

  def assert_successful_run(*args)
    status, _, _ = app_run(*args)
    assert status.success?
  end

  def assert_unsuccessful_run(*args)
    status, _, _ = app_run(*args)
    assert !status.success?
  end

  def assert_stdout(command, expected)
    _, stdout, _ = app_run(command)
    assert stdout.include?(expected)
  end

  def assert_speedup(opts = {})
    ratio  = opts.fetch(:ratio, 0.5)
    from   = opts.fetch(:from, 0)
    first  = @times[from]
    second = @times[from + 1]

    assert (second / first) < ratio, "#{second} was not less than #{ratio} of #{first}"
  end

  def test_command
    "#{BINFILE} test #{@test}"
  end

  setup do
    @test                = "#{app_root}/test/functional/posts_controller_test.rb"
    @test_contents       = File.read(@test)
    @controller          = "#{app_root}/app/controllers/posts_controller.rb"
    @controller_contents = File.read(@controller)

    @times = []

    app_run "bundle check || bundle update", timer: false
    app_run "bundle exec rake db:migrate",   timer: false
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

      # Wait twice to give plenty of time for the wait thread to kick in
      2.times { await_reload }

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

  test "custom commands" do
    assert_stdout "#{BINFILE} custom", "omg"
  end
end
