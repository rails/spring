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
      command_for(args.first).call(args)
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
