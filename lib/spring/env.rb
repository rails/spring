require "pathname"
require "fileutils"

require "spring/version"
require "spring/sid"
require "spring/configuration"

module Spring
  IGNORE_SIGNALS = %w(INT QUIT)

  class Env
    attr_reader :log_file

    def initialize(root = nil)
      @root     = root
      @log_file = File.open(ENV["SPRING_LOG"] || "/dev/null", "a")
    end

    def root
      @root ||= Spring.application_root_path
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
      pidfile = pidfile_path.open('r')
      !pidfile.flock(File::LOCK_EX | File::LOCK_NB)
    rescue Errno::ENOENT
      false
    ensure
      if pidfile
        pidfile.flock(File::LOCK_UN)
        pidfile.close
      end
    end

    def bundle_mtime
      [Bundler.default_lockfile, Bundler.default_gemfile].select(&:exist?).map(&:mtime).max
    end

    def log(message)
      log_file.puts "[#{Time.now}] #{message}"
      log_file.flush
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
