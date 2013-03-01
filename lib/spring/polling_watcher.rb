module Spring
  class PollingWatcher
    attr_reader :mtime, :files, :directories

    def initialize
      @files       = []
      @directories = []
      @mtime       = nil
    end

    def add_files(new_files)
      new_files = new_files.select { |f| File.exist? f }.map { |f| File.realpath f }

      files.concat new_files
      files.uniq!
      reset
    end

    def add_directories(new_directories)
      directories.concat Array(new_directories).map { |d| File.realpath d }
      reset
    end

    def reset
      @mtime = compute_mtime
    end
    alias start   reset
    alias restart reset

    def stale?
      mtime < compute_mtime
    end

    private

    def compute_mtime
      expanded_files.map { |f| File.mtime(f).to_f }.max || 0
    rescue Errno::ENOENT
      # if a file does no longer exist, the watcher is always stale.
      Float::MAX
    end

    def expanded_files
      files + Dir["{#{directories.join(",")}}"]
    end
  end
end
