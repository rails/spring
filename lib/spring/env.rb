require "pathname"
require "spring/sid"
require "fileutils"

class Spring
  IGNORE_SIGNALS = %w(INT QUIT)

  class Env
    attr_reader :root

    def initialize
      @root = Pathname.new(File.expand_path('.'))
    end

    def tmp_path
      path = root.join('tmp/spring')
      FileUtils.mkdir_p(path) unless path.exist?
      path
    end

    def socket_path
      tmp_path.join(SID.sid.to_s)
    end

    def socket_name
      socket_path.to_s
    end

    def pidfile_path
      tmp_path.join("#{SID.sid}.pid")
    end
  end
end
