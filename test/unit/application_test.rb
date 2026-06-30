require_relative "../helper"
require "spring/env"
require "spring/application"
require "timeout"

# Regression tests for https://github.com/rails/spring/issues/724:
# disconnected client raises Errno::EPIPE in #serve, which used to crash
# the application process. Each test exercises one of the EPIPE call
# sites in `Spring::Application#serve` with a `UNIXSocket.pair` whose
# client side has been closed.
class ApplicationTest < ActiveSupport::TestCase
  def setup
    @log_file = File.open(File::NULL, "a")
    @spring_env = Spring::Env.new(log_file: @log_file)
    @manager_read, @manager_write = UNIXSocket.pair
    @app = Spring::Application.new(@manager_write, {}, @spring_env)
    @server_sock = build_disconnected_application_client
  end

  def teardown
    @server_sock&.close
    @manager_read&.close
    @manager_write&.close
    @log_file&.close
  end

  test "#serve does not raise when the client disconnects before the cached-preload-success write" do
    @app.define_singleton_method(:preloaded?) { true }

    with_saved_stdio { @app.serve(@server_sock) }

    assert_manager_handshake_complete
  end

  test "#serve does not raise when the client disconnects before the fresh-preload-success write" do
    @app.define_singleton_method(:preload) {}

    with_saved_stdio { @app.serve(@server_sock) }

    assert_manager_handshake_complete
  end

  test "#serve does not raise when the client disconnects during preload-failure recovery" do
    @app.define_singleton_method(:preload) { raise RuntimeError, "simulated preload failure" }

    with_saved_stdio { @app.serve(@server_sock) }

    assert_manager_handshake_complete
  end

  private

  # Simulates a client that handed off its STDOUT/STDERR/STDIN to the
  # application and then died. The 3 stream FDs sent to the application:
  #
  #   - STDOUT, STDERR: write-ends of pipes whose read ends are closed, so
  #     writes (e.g. via `print_exception`) raise Errno::EPIPE.
  #   - STDIN: read-end of a pipe whose write end is closed, so reads return
  #     EOF (matches a dead client's STDIN).
  #
  # The UNIXSocket itself is also closed on the client side, so writes to
  # `client` (e.g. `client.puts(0)`) raise Errno::EPIPE too.
  def build_disconnected_application_client
    server_sock, client_sock = UNIXSocket.pair

    out_r, out_w = IO.pipe
    err_r, err_w = IO.pipe
    in_r,  in_w  = IO.pipe
    [[out_r, out_w], [err_r, err_w]].each do |r, w|
      client_sock.send_io(w)
      r.close
      w.close
    end
    client_sock.send_io(in_r)
    in_r.close
    in_w.close

    client_sock.close
    server_sock
  end

  # Application#serve reopens STDOUT, STDERR, and STDIN to the streams it
  # received from the client (and to its log_file in `reset_streams`).
  # Save and restore the test runner's streams around the call.
  def with_saved_stdio
    saved_out = STDOUT.dup
    saved_err = STDERR.dup
    saved_in  = STDIN.dup
    yield
  ensure
    STDOUT.reopen(saved_out) if saved_out
    STDERR.reopen(saved_err) if saved_err
    STDIN.reopen(saved_in)   if saved_in
    [saved_out, saved_err, saved_in].compact.each { |io| io.close rescue nil }
  end

  # `serve` writes two newlines to the manager: an early "got client" ack
  # and a no-pid response from the rescue handler. Without the second,
  # `ApplicationManager#run` blocks forever on `child.gets.to_i` and the
  # server's single-threaded accept loop deadlocks. Timeout + flunk fails
  # loudly instead of stalling the suite.
  def assert_manager_handshake_complete
    acks = Timeout.timeout(2) { [@manager_read.gets, @manager_read.gets] }
    assert_equal ["\n", "\n"], acks
  rescue Timeout::Error
    flunk "Application#serve did not send the no-pid response to the manager " \
          "— ApplicationManager#run will block on child.gets.to_i and deadlock " \
          "the server's accept loop"
  end

  test "#reset_reline_io_gate re-decides Reline::IOGate when streams are TTYs" do
    new_gate = Object.new

    with_fake_reline(decided_gate: new_gate) do
      with_tty_streams do
        with_env("TERM" => "xterm-256color") do
          @app.reset_reline_io_gate
        end
      end

      assert_equal new_gate, ::Reline::IOGate
    end
  end

  test "#reset_reline_io_gate is a no-op when Reline is not defined" do
    without_reline do
      refute defined?(::Reline)

      assert_nil @app.reset_reline_io_gate
    end
  end

  test "#reset_reline_io_gate is a no-op when STDOUT is not a TTY (piped)" do
    original_gate = Object.new

    with_fake_reline(decided_gate: Object.new, current_gate: original_gate) do
      with_env("TERM" => "xterm-256color") do
        # $stdout in the test runner is not a TTY; the method must bail out
        # without calling decide_io_gate or touching the gate.
        @app.reset_reline_io_gate
      end

      assert_equal original_gate, ::Reline::IOGate
    end
  end

  test "#reset_reline_io_gate is a no-op when TERM is dumb" do
    original_gate = Object.new

    with_fake_reline(decided_gate: Object.new, current_gate: original_gate) do
      with_tty_streams do
        with_env("TERM" => "dumb") do
          @app.reset_reline_io_gate
        end
      end

      assert_equal original_gate, ::Reline::IOGate
    end
  end

  # Build a minimal `Reline` module mimicking the shape Spring's
  # `reset_reline_io_gate` inspects: `Reline::IO.decide_io_gate` (modern
  # Reline) plus the `Reline::IOGate` constant. `decided_gate` is what
  # `decide_io_gate` returns; `current_gate` is the pre-existing (stale)
  # value of `Reline::IOGate`. Any pre-existing `::Reline` constant is
  # restored afterwards so the global state doesn't leak to other tests.
  def with_fake_reline(decided_gate:, current_gate: :stale_gate_from_preload)
    original_reline = ::Reline if defined?(::Reline)
    Object.send(:remove_const, :Reline) if defined?(::Reline)

    reline = Module.new
    reline.const_set(:IOGate, current_gate)
    io = Module.new
    io.define_singleton_method(:decide_io_gate) { decided_gate }
    reline.const_set(:IO, io)

    Object.const_set(:Reline, reline)
    yield
  ensure
    Object.send(:remove_const, :Reline) if defined?(::Reline)
    if original_reline
      verbose_was = $VERBOSE
      $VERBOSE = nil
      begin
        Object.const_set(:Reline, original_reline)
      ensure
        $VERBOSE = verbose_was
      end
    end
  end

  # Run the block as if `Reline` were not loaded, restoring any pre-existing
  # `::Reline` constant afterwards so the global state doesn't leak.
  def without_reline
    original_reline = ::Reline if defined?(::Reline)
    Object.send(:remove_const, :Reline) if defined?(::Reline)
    yield
  ensure
    if original_reline
      verbose_was = $VERBOSE
      $VERBOSE = nil
      begin
        Object.const_set(:Reline, original_reline)
      ensure
        $VERBOSE = verbose_was
      end
    end
  end

  # Run the block with $stdin/$stdout/$stderr reporting as TTYs, restoring
  # them afterwards. A stub is used instead of a real PTY so the test doesn't
  # depend on /dev/ptmx being available in the CI environment.
  def with_tty_streams
    orig_in  = $stdin
    orig_out = $stdout
    orig_err = $stderr
    $stdin  = TTYStub.new(orig_in)
    $stdout = TTYStub.new(orig_out)
    $stderr = TTYStub.new(orig_err)
    yield
  ensure
    $stdin  = orig_in
    $stdout = orig_out
    $stderr = orig_err
  end

  def with_env(changes)
    saved = changes.transform_values { |k| ENV[k] }
    changes.each { |k, v| ENV[k] = v }
    yield
  ensure
    saved.each do |k, v|
      if v.nil?
        ENV.delete(k)
      else
        ENV[k] = v
      end
    end
  end

  # Minimal IO wrapper that answers `tty?`/`isatty` truthily and forwards
  # everything else to the wrapped IO.
  class TTYStub < SimpleDelegator
    def tty?; true; end
    alias isatty tty?
  end
end
