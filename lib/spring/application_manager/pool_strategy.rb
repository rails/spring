require 'securerandom'

module Spring
  module ApplicationManager
    class PoolStrategy
      class Worker
        attr_reader :pid, :socket
        attr_accessor :on_done

        def initialize(env, args)
          @spring_env = Env.new
          path = @spring_env.tmp_path.join("#{SecureRandom.uuid}.sock").to_s
          @server = UNIXServer.open(path)

          Bundler.with_clean_env do
            @pid =
              Process.spawn(env.merge("SPRING_SOCKET" => path), *args)
            log "worker spawned"
          end

          @socket = @server.accept
        end

        def await_boot
          @pid = socket.gets.to_i
          Process.detach(pid)
          @wait_thread = start_wait_thread(pid, socket) unless pid.zero?
        end

        def kill(sig = 9)
          Process.kill(sig, pid)
        rescue Errno::ESRCH
        end

        def join
          @wait_thread.join if @wait_thread
        end

        protected

        def start_wait_thread(pid, child)
          Thread.new do
            begin
              Process.wait pid
            rescue Errno::ECHILD
              # Not sure why this gets raised
            rescue StandardError => e
              log "error waiting for worker: #{e.class}: #{e.message}"
            end

            kill
            log "child #{pid} shutdown"

            on_done.call(self) if on_done
          end
        end

        def log(message)
          @spring_env.log "[worker:#{pid}] #{message}"
        end
      end

      class WorkerPool
        def initialize(app_env, *app_args)
          @app_env = app_env
          @app_args = app_args
          @spring_env = Env.new

          @workers = []
          @workers_in_use = []
          @spawning_workers = []

          @check_mutex = Mutex.new
          @workers_mutex = Mutex.new

          run
        end

        def add_worker
          worker = Worker.new(@app_env, @app_args)
          worker.on_done = method(:worker_done)
          @workers_mutex.synchronize { @spawning_workers << worker }
          Thread.new do
            worker.await_boot
            log "+ worker #{worker.pid}"
            @workers_mutex.synchronize do
              @spawning_workers.delete(worker)
              @workers << worker
            end
          end
        end

        def worker_done(worker)
          log "- worker #{worker.pid}"
          @workers_mutex.synchronize do
            @workers_in_use.delete(worker)
          end
        end

        def get_worker(spawn_new = true)
          add_worker if spawn_new && all_size == 0

          worker = nil
          while worker.nil? && all_size > 0
            @workers_mutex.synchronize do
              worker = @workers.shift
              @workers_in_use << worker if worker
            end
            break if worker
            sleep 1
          end

          Thread.new { check_min_free_workers } if spawn_new

          worker
        end

        def check_min_free_workers
          if @check_mutex.try_lock
            while all_size < Spring.pool_min_free_workers
              unless Spring.pool_spawn_parallel
                sleep 0.1 until @workers_mutex.synchronize { @spawning_workers.empty? }
              end
              add_worker
            end
            @check_mutex.unlock
          end
        end

        def all_size
          @workers_mutex.synchronize { @workers.size + @spawning_workers.size }
        end

        def stop!
          if spawning_worker_pids.include?(nil)
            log "Waiting for workers to quit..."
            sleep 0.1 while spawning_worker_pids.include?(nil)
          end

          waiting_workers =
            @workers_mutex.synchronize do
              (@spawning_workers + @workers_in_use + @workers).each(&:kill)
            end
          waiting_workers.each(&:join)
        end

        protected

        def spawning_worker_pids
          @spawning_workers.map { |worker| worker.pid }
        end

        def run
          check_min_free_workers
        end

        def log(message)
          @spring_env.log "[worker:pool] #{message}"
        end
      end

      def initialize(app_env)
        @app_env    = app_env
        @spring_env = Env.new
        @pool       =
          WorkerPool.new(
            {
              "RAILS_ENV"           => app_env,
              "RACK_ENV"            => app_env,
              "SPRING_ORIGINAL_ENV" => JSON.dump(Spring::ORIGINAL_ENV),
              "SPRING_PRELOAD"      => "1",
            },
            Spring.ruby_bin,
            "-I", File.expand_path("../..", $LOADED_FEATURES.grep(/bundler\/setup\.rb$/).first),
            "-I", File.expand_path("../..", __FILE__),
            "-e", "require 'spring/application/boot'"
          )
      end

      # Returns the name of the screen running the command, or nil if the application process died.
      def run(client)
        pid = nil
        with_child do |child|
          child.socket.send_io(client)
          IO.select([child.socket])
          child.socket.gets or raise Errno::EPIPE
          IO.select([child.socket])
          pid = child.socket.gets.to_i
        end

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

        @pool.stop!
      rescue Errno::ESRCH, Errno::ECHILD
        # Don't care
      end

      protected

      attr_reader :app_env, :spring_env

      def log(message)
        spring_env.log "[application_manager:#{app_env}] #{message}"
      end

      def with_child
        yield(@pool.get_worker)
      end
    end
  end
end
