require "spring/configuration"
require "spring/client/command"
require "spring/client/run"
require "spring/client/help"
require "spring/client/binstub"
require "spring/client/stop"
require "spring/client/status"

module Spring
  module Client
    COMMANDS = {
      "help"    => Client::Help,
      "binstub" => Client::Binstub,
      "stop"    => Client::Stop,
      "status"  => Client::Status
    }

    def self.run(args)
      command_for(args.first).call(args)
    rescue ClientError => e
      $stderr.puts e.message
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
