
module Expedite
  class Error < StandardError
  end

  class CommandNotFound < Error
  end

  class UnknownError < Error
  end

  class AgentNotFoundError < Error
  end
end
