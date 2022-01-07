# Based on https://github.com/rails/spring/blob/master/lib/spring/client/status.rb
require 'expedite'
require 'expedite/cli/server'
require 'expedite/cli/stop'

module Expedite
  module Cli
    class Status
      def run(args)
        require 'expedite/server/controller'

        ctrl = Expedite::Server::Controller.new(foreground: true)
        if ctrl.running?
          puts "Expedite is running (pid=#{ctrl.pid})"
          puts
          print_process ctrl.pid
          Expedite.agent("__server__").invoke("application_pids").each do |pid|
            print_process pid
          end
        else
          puts "Expedite is not running"
        end
      end

      def summary
        'Expedite server status'
      end

      def print_process(pid)
        puts `ps -p #{pid} -o pid= -o command=`
      end
    end
  end
end
