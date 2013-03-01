module Spring
  class PollingWatcher
    attr_reader :root_path, :files, :directories

    def initialize(root_path, listener_options = {})
      @root_path        = File.realpath(root_path)
      @polling          = false

      @files            = []
      @directories      = []
    end

    def add_files(new_files)
      new_files = Array(new_files).select { |f| File.exist?(f) }

      files.concat new_files.map { |f| File.realpath(f) }
      files.uniq!
    end

    def add_directories(new_directories)
      directories.concat Array(new_directories).map { |d| File.realpath(d) }
    end

    def start
      @polling = true
      @watched_files = calculate_watched_file_hash
    end
    alias_method :reset,   :start
    alias_method :restart, :start

    def stop
      @polling = false
    end

    def stale?
      @watched_files != calculate_watched_file_hash if @polling
    end

    private

    def calculate_watched_file_hash
      Hash[files_within_root_path.map { |f| [f, mtime_of(f)] }]
    end

    def mtime_of(file)
      File.exist?(file) ? File.mtime(file).to_f : Float::MAX
    end

    def files_within_root_path
      expanded_files.select { |f| File.fnmatch?(File.join(root_path,'**'), f) }
    end

    def expanded_files
      files + directories.map { |d| Dir.glob("#{d}/**") }.flatten
    end
  end
end

