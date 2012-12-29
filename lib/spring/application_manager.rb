require "socket"
require "spring/application"
require "mutex_m"

class Spring
  class ApplicationManager
    include Mutex_m

    attr_reader :pid, :child, :env

    def initialize(env)
      super()
      @env = env
    end

    def start
      start_child
      start_wait_thread
    end

    def restart
      # Restarting is a background operation. If it fails, we don't want
      # any terminal output. The user will see the output when they next
      # try to run a command.
      start_child(true)
    end

    def alive?
      @pid
    end

    def run(client)
      @client = client

      synchronize do
        start unless alive?

        begin
          child.send_io @client
        rescue Errno::EPIPE
          # EPIPE indicates child has died but has not been collected by the wait thread yet
          start
          child.send_io @client
        end
      end
    ensure
      @client.close
      @client = nil
    end

    private

    def start_child(silence = false)
      @child, child_socket = UNIXSocket.pair
      @pid = fork {
        [STDOUT, STDERR].each { |s| s.reopen('/dev/null', 'w') } if silence
        @client.close if @client
        ENV['RAILS_ENV'] = ENV['RACK_ENV'] = env
        Application.new(child_socket).start
      }
      child_socket.close
    end

    def start_wait_thread
      @wait_thread = Thread.new {
        Thread.current.abort_on_exception = true

        while alive?
          _, status = Process.wait2(pid)
          @pid = nil

          # In the forked child, this will block forever, so we won't
          # return to the next iteration of the loop.
          synchronize { restart if !alive? && status.success? }
        end
      }
    end
  end
end
