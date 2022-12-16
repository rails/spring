require 'expedite/cli/rails'
require 'expedite/cli/server'
require 'expedite/cli/status'
require 'expedite/cli/stop'

module Expedite
  module Cli
    class UnknownCommandError < StandardError
    end

    class Help
      def run(args)
        puts "Expected: <command>"
        puts
        puts "Commands:"

        cmds = Expedite::Cli.commands
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

    def commands
      return @commands unless @commands.nil?

      cmds = {
        'help'   => Cli::Help,
        'server' => Cli::Server,
        'status' => Cli::Status,
        'stop'   => Cli::Stop,
      }
      cmds['rails'] = Cli::Rails if Gem.loaded_specs["rails"]
      @commands = cmds
    end

    def run(args)
      command(args.first).run(args[1..])
    rescue UnknownCommandError => e
      STDERR.puts e
      Cli::Help.new.run([])
    end

    def command(cmd)
      klass = commands[cmd]
      raise UnknownCommandError, "Unknown command '#{cmd}'" if klass.nil?
      klass.new
    end
  end
end
