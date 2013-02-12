require 'fiddle'

module Spring
  module SID
    if RUBY_VERSION >= '2.0.0'
      handle = Fiddle::Handle
    else
      handle = DL::Handle
    end

    FUNC = Fiddle::Function.new(
      handle::DEFAULT['getsid'],
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
