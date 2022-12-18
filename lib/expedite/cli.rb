require 'expedite/cli/server'
require 'expedite/cli/stop'

module Expedite
  module Cli
    class Help
      def run(args)
        puts "Expected: <command>"
        puts
        puts "Commands:"

        cmds = Expedite::Cli::COMMANDS
        cmds.keys.sort!.each do |cmd|
          c = cmds[cmd].new
          puts "  #{cmd}: #{c.summary}"
        end
      end

      def summary
        'Prints usage documentation'
      end
    end

    module_function

    COMMANDS = {
      'help'   => Cli::Help,
      'server' => Cli::Server,
      'stop'   => Cli::Stop,
    }

    def run(args)
      command(args.first).run(args[1..])
    end

    def command(cmd)
      klass = COMMANDS[cmd]
      raise NotImplementedError, "Unknown command '#{cmd}'" if klass.nil?
      klass.new
    end
  end
end
