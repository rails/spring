require "pathname"
require "fileutils"
require "digest/md5"
require "tmpdir"

require "spring/version"
require "spring/sid"
require "spring/configuration"

module Spring
  IGNORE_SIGNALS = %w(INT QUIT)

  class Env
    attr_reader :log_file

    def initialize(root = nil)
      @root         = root
      @project_root = root
      @log_file     = File.open(ENV["SPRING_LOG"] || File::NULL, "a")
    end

    def root
      @root ||= Spring.application_root_path
    end

    def project_root
      @project_root ||= Spring.project_root_path
    end

    def version
      Spring::VERSION
    end

    def tmp_path
      path = Pathname.new(Dir.tmpdir + "/spring")
      FileUtils.mkdir_p(path) unless path.exist?
      path
    end

    def application_id
      Digest::MD5.hexdigest(project_root.to_s)
    end

    def socket_path
      tmp_path.join(application_id)
    end

    def socket_name
      socket_path.to_s
    end

    def pidfile_path
      tmp_path.join("#{application_id}.pid")
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
      pidfile = pidfile_path.open('r+')
      !pidfile.flock(File::LOCK_EX | File::LOCK_NB)
    rescue Errno::ENOENT
      false
    ensure
      if pidfile
        pidfile.flock(File::LOCK_UN)
        pidfile.close
      end
    end

    def log(message)
      log_file.puts "[#{Time.now}] [#{Process.pid}] #{message}"
      log_file.flush
    end
  end
end
