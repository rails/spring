require 'fiddle'

class Spring
  module SID
    FUNC = Fiddle::Function.new(
      DL::Handle::DEFAULT['getsid'],
      [Fiddle::TYPE_INT],
      Fiddle::TYPE_INT
    )

    def self.sid(pid = 0)
      FUNC.call(pid)
    end

    def self.pgid
      Process.getpgid(sid)
    end
  end
end
