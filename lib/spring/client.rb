require "spring/configuration"
require "spring/client/command"
require "spring/client/run"
require "spring/client/help"
require "spring/client/binstub"

module Spring
  module Client
    COMMANDS = {
      "help"    => Client::Help,
      "binstub" => Client::Binstub
    }

    def self.run(args)
      Spring.verify_environment!
      command_for(args.first).call(args)
    rescue InvalidEnvironmentError => e
      STDERR.puts e
      exit 1
    end

    def self.command_for(name)
      if Spring.command?(name)
        Client::Run
      else
        COMMANDS.fetch(name) { Client::Help }
      end
    end
  end
end
