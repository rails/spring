require_relative "../helper"
require "spring/env"
require "spring/server"
require "fileutils"
require "tmpdir"

# Regression test for https://github.com/rails/spring/issues/724:
# disconnected client raises Errno::EPIPE in #serve, which used to crash
# the accept loop and require `spring stop` to recover.
class ServerTest < ActiveSupport::TestCase
  def setup
    @tmpdir   = Dir.mktmpdir("spring-server-test")
    @log_file = File.open(File::NULL, "a")
    @env      = Spring::Env.new(log_file: @log_file)
    # Pin the env's pidfile path to the test's tmpdir so we don't pollute
    # the user's spring tmp directory.
    pidfile_path = Pathname.new(File.join(@tmpdir, "spring.pid"))
    @env.define_singleton_method(:pidfile_path) { pidfile_path }
  end

  def teardown
    @log_file&.close
    FileUtils.remove_entry(@tmpdir) if @tmpdir
  end

  test "#serve does not raise when the client disconnects before the version banner is sent" do
    server = Spring::Server.new(env: @env)
    server_sock, client_sock = UNIXSocket.pair
    client_sock.close

    assert_nothing_raised do
      with_saved_stdio { server.serve(server_sock) }
    end
  ensure
    server_sock&.close
  end

  private

  # Server#serve calls `redirect_output` in `ensure`, which reopens
  # STDOUT/STDERR to env.log_file. Save and restore the test runner's
  # streams around the call so subsequent tests still log normally.
  def with_saved_stdio
    saved_out = STDOUT.dup
    saved_err = STDERR.dup
    yield
  ensure
    STDOUT.reopen(saved_out) if saved_out
    STDERR.reopen(saved_err) if saved_err
    [saved_out, saved_err].compact.each { |io| io.close rescue nil }
  end
end
