# Based on https://github.com/rails/spring/blob/master/lib/spring/application_manager.rb

require 'bundler'
require 'expedite/failsafe_thread'
require 'expedite/send_json'
require 'expedite/variants'

module Expedite
  class ApplicationManager
    include SendJson

    attr_reader :pid, :child, :variant, :env, :status

    def initialize(variant, env)
      @variant    = variant
      @env        = env
      @mutex      = Mutex.new
      @state      = :running
      @pid        = nil
    end

    def log(message)
      env.log "[application_manager:#{variant}] #{message}"
    end

    # We're not using @mutex.synchronize to avoid the weird "<internal:prelude>:10"
    # line which messes with backtraces in e.g. rspec
    def synchronize
      @mutex.lock
      yield
    ensure
      @mutex.unlock
    end

    def start
      start_child
    end

    def restart
      return if @state == :stopping
      start_child(true)
    end

    def alive?
      @pid
    end

    def with_child
      synchronize do
        if alive?
          begin
            yield child
          rescue Errno::ECONNRESET, Errno::EPIPE
            # The child has died but has not been collected by the wait thread yet,
            # so start a new child and try again.
            log "child dead; starting"
            start
            yield child
          end
        else
          log "child not running; starting"
          start
          yield child
        end
      end
    end

    # Returns the pid of the process running the command, or nil if the application process died.
    def run(client)
      @client = client
      with_child do |child|
        child.send_io client
        child.gets or raise Errno::EPIPE
      end

      pid = child.gets.to_i

      unless pid.zero?
        log "got worker pid #{pid}"
        pid
      end
    rescue Errno::ECONNRESET, Errno::EPIPE => e
      log "#{e} while reading from child; returning no pid"
      nil
    ensure
      client.close
    end

    def stop
      log "stopping"
      @state = :stopping

      if pid
        Process.kill('TERM', pid)
        Process.wait(pid)
      end
    rescue Errno::ESRCH, Errno::ECHILD
      # Don't care
    end

    def parent
      Expedite::Variants.lookup(variant).parent
    end

    private

    def start_child(preload = false)
      if parent
        fork_child(preload)
      else
        spawn_child(preload)
      end
    end

    def fork_child(preload = false)
      @child, child_socket = UNIXSocket.pair

      # Compose command
      wr, rd = UNIXSocket.pair
      wr.send_io STDOUT
      wr.send_io STDERR
      wr.send_io STDIN

      send_json wr, 'args' => ['expedite/boot', variant], 'env' => {}
      wr.send_io child_socket
      wr.send_io env.log_file
      wr.close

      @pid = env.applications[parent].run(rd)

      start_wait_thread(pid, child) if child.gets
      child_socket.close
    end

    def spawn_child(preload = false)
      @child, child_socket = UNIXSocket.pair

      Bundler.with_original_env do
        bundler_dir = File.expand_path("../..", $LOADED_FEATURES.grep(/bundler\/setup\.rb$/).first)
        @pid = Process.spawn(
          {
            "EXPEDITE_VARIANT" => variant,
          },
          "ruby",
          *(bundler_dir != RbConfig::CONFIG["rubylibdir"] ? ["-I", bundler_dir] : []),
          "-I", File.expand_path("../..", __FILE__),
          "-e", "require 'expedite/application/boot'",
          3 => child_socket,
          4 => env.log_file,
        )
      end

      start_wait_thread(pid, child) if child.gets
      child_socket.close
    end

    def start_wait_thread(pid, child)
      Process.detach(pid)

      Expedite.failsafe_thread do
        # The recv can raise an ECONNRESET, killing the thread, but that's ok
        # as if it does we're no longer interested in the child
        loop do
          IO.select([child])
          break if child.recv(1, Socket::MSG_PEEK).empty?
          sleep 0.01
        end

        log "child #{pid} shutdown"

        synchronize {
          if @pid == pid
            @pid = nil
            restart
          end
        }
      end
    end
  end
end
