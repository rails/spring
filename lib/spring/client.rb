require "spring/configuration"
require "spring/client/command"
require "spring/client/run"
require "spring/client/help"
require "spring/client/binstub"
require "spring/client/start"
require "spring/client/stop"
require "spring/client/status"
require "spring/client/rails"

module Spring
  module Client
    COMMANDS = {
      "help"    => Client::Help,
      "binstub" => Client::Binstub,
      "start"   => Client::Start,
      "stop"    => Client::Stop,
      "status"  => Client::Status,
      "rails"   => Client::Rails
    }

    def self.run(args)
      command_for(args.first).call(args)
    rescue CommandNotFound
      Client::Help.call(args)
    rescue ClientError => e
      $stderr.puts e.message
      exit 1
    end

    def self.command_for(name)
      COMMANDS[name] || Client::Run
    end
  end
end
