# encoding: utf-8
require "helper"
require "acceptance/helper"
require "io/wait"
require "timeout"
require "spring/sid"
require "spring/client"

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

  def assert_app_reloaded
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
end
