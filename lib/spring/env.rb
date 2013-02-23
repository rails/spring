require "pathname"
require "fileutils"

require "spring/version"
require "spring/sid"

module Spring
  IGNORE_SIGNALS = %w(INT QUIT)

  class Env
    attr_reader :root

    def initialize(root = nil)
      @root = root || Pathname.new(File.expand_path('.'))
    end

    def version
      Spring::VERSION
    end

    def tmp_path
      path = default_tmp_path
      FileUtils.mkdir_p(path) unless path.exist?
      path
    end

    def socket_path
      tmp_path.join("spring")
    end

    def socket_name
      socket_path.to_s
    end

    def pidfile_path
      tmp_path.join("spring.pid")
    end

    def pid
      pidfile_path.exist? ? pidfile_path.read.to_i : nil
    rescue Errno::ENOENT
      # This can happen if the pidfile is removed after we check it
      # exists
    end

    def app_name
      root.basename
    end

    def server_running?
      if pidfile_path.exist?
        pidfile = pidfile_path.open('r')
        !pidfile.flock(File::LOCK_EX | File::LOCK_NB)
      else
        false
      end
    ensure
      if pidfile
        pidfile.flock(File::LOCK_UN)
        pidfile.close
      end
    end

    private

    def default_tmp_path
      if ENV['SPRING_TMP_PATH']
        Pathname.new(ENV['SPRING_TMP_PATH'])
      else
        root.join('tmp/spring')
      end
    end
  end
end
