require "spring/client"

class Spring
  def self.run(args)
    exit new.run(args)
  end

  def run(args)
    if self.class.command_registered?(args.first)
      Client::Run.call args
    else
      Client::Help.call args
    end
  end
end
