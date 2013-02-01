require "spring/client/command"
require "spring/client/run"
require "spring/client/help"

module Spring
  module Client
    def self.run(args)
      exit command_for(args.first).call(args)
    end

    def self.command_for(name)
      if Spring.command_registered?(name)
        Client::Run
      else
        Client::Help
      end
    end
  end
end
