
# Based on https://github.com/rails/spring/blob/master/lib/spring/client/run.rb

require 'bundler'
require 'rbconfig'
require 'socket'

require 'expedite/client/invoke'
require 'expedite/env'
require 'expedite/errors'
require 'expedite/send_json'

module Expedite
  module Client
    class Exec < Invoke
      FORWARDED_SIGNALS = %w(INT QUIT USR1 USR2 INFO WINCH) & Signal.list.keys

      def initialize(env: nil, variant: nil)
        super

        @signal_queue  = []
      end

      def call(*args)
        @args = args
        begin
          connect
        rescue Errno::ENOENT, Errno::ECONNRESET, Errno::ECONNREFUSED
          cold_run
        else
          warm_run
        end
      ensure
        server.close if server
      end

      def warm_run
        run
      rescue CommandNotFound
        raise
        require "expedite/command"

        if Expedite.command(args.first)
          # Command installed since Expedite started
          stop_server
          cold_run
        else
          raise
        end
      end

      def cold_run
        boot_server
        connect
        run
      end

      def run
        status = perform(*@args)

        exit status.to_i
      rescue Errno::ECONNRESET
        exit 1
      end

      def verify_server_version
        server_version = server.gets.chomp
        if server_version != env.version
          $stderr.puts "There is a version mismatch between the Expedite client " \
                         "(#{env.version}) and the server (#{server_version})."

          if server_booted?
            $stderr.puts "We already tried to reboot the server, but the mismatch is still present."
            exit 1
          else
            $stderr.puts "Restarting to resolve."
            stop_server
            cold_run
          end
        end
      end

      def queue_signals
        FORWARDED_SIGNALS.each do |sig|
          trap(sig) { @signal_queue << sig }
        end
      end

      def suspend_resume_on_tstp_cont(pid)
        trap("TSTP") {
          log "suspended"
          Process.kill("STOP", pid.to_i)
          Process.kill("STOP", Process.pid)
        }
        trap("CONT") {
          log "resumed"
          Process.kill("CONT", pid.to_i)
        }
      end

      def forward_signals(application)
        @signal_queue.each { |sig| kill sig, application }

        FORWARDED_SIGNALS.each do |sig|
          trap(sig) { forward_signal sig, application }
        end
      end

      def forward_signal(sig, application)
        if kill(sig, application) != 0
          # If the application process is gone, then don't block the
          # signal on this process.
          trap(sig, 'DEFAULT')
          Process.kill(sig, Process.pid)
        end
      end

      def kill(sig, application)
        application.puts(sig)
        application.gets.to_i
      end
    end
  end
end
