class Spring
  class ApplicationWatcher
    attr_reader :mtime, :files, :globs

    def initialize
      @files = []
      @globs = []
      @mtime = nil
    end

    def add_files(new_files)
      files.concat new_files.select { |f| File.exist?(f) }
      files.uniq!
      reset
    end

    def add_globs(new_globs)
      globs.concat new_globs
      reset
    end

    def reset
      @mtime = compute_mtime
    end

    def stale?
      mtime < compute_mtime
    end

    private

    def compute_mtime
      expanded_files.map { |f| File.mtime(f).to_f }.max || 0
    end

    def expanded_files
      files + Dir["{#{globs.join(",")}}"]
    end
  end
end
