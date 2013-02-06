require "spring/configuration"
require "spring/client/command"
require "spring/client/run"
require "spring/client/help"
require "spring/client/binstub"
require "spring/client/stop"

module Spring
  module Client
    COMMANDS = {
      "help"    => Client::Help,
      "binstub" => Client::Binstub,
      "stop"    => Client::Stop
    }

    def self.run(args)
      command_for(args.first).call(args)
    rescue ClientError => e
      STDERR.puts e.message
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
