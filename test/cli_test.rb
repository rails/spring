require "test_helper"
require "expedite/cli/status"
require "expedite/server/controller"

class CliTest < Minitest::Test
  def setup
    @srv = Expedite::Server::Controller.new
  end

  def teardown
    @srv.stop
  end

  def test_status
    # it should run without raising exceptions
    cmd = Expedite::Cli::Status.new
    cmd.run([])

    # Start server
    fork do
      @srv.boot
      exit 0
    end

    sleep 1
    cmd.run([])
    assert_equal @srv.running?, true
  end

  def test_stop
    cmd = Expedite::Cli::Stop.new
    cmd.run([])

    # Start server
    fork do
      @srv.boot
      exit 0
    end

    sleep 1
    cmd.run([])
    assert_equal @srv.running?, false
  end
end