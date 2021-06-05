# Based on https://github.com/rails/spring/blob/master/lib/spring/server.rb
require 'json'
require 'socket'
require "expedite/application_manager"
require "expedite/env"
require 'expedite/load_helper'
require "expedite/signals"

module Expedite
  class Server
    include LoadHelper
    include Signals

    def self.boot(options = {})
      new(options).boot
    end

    attr_reader :env

    def initialize(foreground: true, env: nil)
      @foreground   = foreground
      @env          = env || default_env
      @pidfile      = @env.pidfile_path.open('a')
      @mutex        = Mutex.new
    end

    def foreground?
      @foreground
    end

    def log(message)
      env.log "[server] #{message}"
    end

    def boot
      load_helper

      write_pidfile
      set_pgid unless foreground?
      ignore_signals unless foreground?
      set_exit_hook
      set_process_title
      start_server
      exit 0
    end

    def pid
      @env.pidfile_path.read.to_i
    rescue Errno::ENOENT
      nil
    end

    def running?
      pidfile = @env.pidfile_path.open('r+')
      !pidfile.flock(File::LOCK_EX | File::LOCK_NB)
    rescue Errno::ENOENT
      false
    ensure
      if pidfile
        pidfile.flock(File::LOCK_UN)
        pidfile.close
      end
    end

    # timeout: Defaults to 2 seconds
    def stop
      if running?
        timeout = Time.now + @env.graceful_termination_timeout
        kill 'TERM'
        sleep 0.1 until !running? || Time.now >= timeout

        if running?
          kill 'KILL'
          :killed
        else
          :stopped
        end
      else
        :not_running
      end
    end

    def kill(sig)
      pid = self.pid
      Process.kill(sig, pid) if pid
    rescue Errno::ESRCH
      # already dead
    end

    def start_server
      server = UNIXServer.open(env.socket_path)
      log "started on #{env.socket_path}"
      loop { serve server.accept }
    rescue Interrupt
    end

    def serve(client)
      log "accepted client"
      client.puts env.version

      app_client = client.recv_io
      command    = JSON.load(client.read(client.gets.to_i))

      args, variant = command.values_at('args', 'variant')
      cmd = args.first
      if true #Expedite.command(cmd)
        log "running command #{cmd}"
        client.puts

        target = env.applications[variant]
        client.puts target.run(app_client)
      else
        log "command not found #{cmd}"
        client.close
      end
    rescue SocketError => e
      raise e unless client.eof?
    ensure
      redirect_output
    end

    # Boot the server into the process group of the current session.
    # This will cause it to be automatically killed once the session
    # ends (i.e. when the user closes their terminal).
    def set_pgid
      # Process.setpgid(0, SID.pgid)
    end

    # Ignore SIGINT and SIGQUIT otherwise the user typing ^C or ^\ on the command line
    # will kill the server/application.
    def ignore_signals
      IGNORE_SIGNALS.each { |sig| trap(sig, "IGNORE") }
    end

    def set_exit_hook
      server_pid = Process.pid

      # We don't want this hook to run in any forks of the current process
      at_exit { shutdown if Process.pid == server_pid }
    end

    def shutdown
      log "shutting down"

      [env.socket_path, env.pidfile_path].each do |path|
        if path.exist?
          path.unlink rescue nil
        end
      end

      env.applications.values.map { |a| Expedite.failsafe_thread { a.stop } }.map(&:join)
    end

    def write_pidfile
      if @pidfile.flock(File::LOCK_EX | File::LOCK_NB)
        @pidfile.truncate(0)
        @pidfile.write("#{Process.pid}\n")
        @pidfile.fsync
      else
        raise "Failed to lock #{@env.pidfile_path}"
      end
    end

    # We need to redirect STDOUT and STDERR, otherwise the server will
    # keep the original FDs open which would break piping. (e.g.
    # `spring rake -T | grep db` would hang forever because the server
    # would keep the stdout FD open.)
    def redirect_output
      [STDOUT, STDERR].each { |stream| stream.reopen(env.log_file) }
    end

    def set_process_title
      $0 = "expedite server | #{env.app_name}"
    end

    private

    def default_env
      Env.new(log_file: default_log_file)
    end

    def default_log_file
      if foreground? && !ENV["SPRING_LOG"]
        $stdout
      else
        nil
      end
    end
  end
end
