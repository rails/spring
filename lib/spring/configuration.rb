require "spring/errors"

module Spring
  @connect_timeout = 5
  @boot_timeout = 20

  class << self
    attr_accessor :application_root, :connect_timeout, :boot_timeout
    attr_writer :quiet

    def gemfile
      require "bundler"

      if /\s1.9.[0-9]/ ===  Bundler.ruby_scope.gsub(/[\/\s]+/,'')
        Pathname.new(ENV["BUNDLE_GEMFILE"] || "Gemfile").expand_path
      else
        # default_gemfile autoloads SharedHelpers, but this causes deadlocks because it occurs in a separate thread.
        # application/boot.rb loads the application in the main thread which calls bundler/setup and requires
        # shared_helpers instead of autoloading. Due to a ruby bug, autoloading and requiring the same file in separate
        # threads can cause deadlocks. Requiring shared_helpers here prevents it from being autoloaded.
        require "bundler/shared_helpers"
        Bundler.default_gemfile
      end
    end

    def gemfile_lock
      case gemfile.to_s
      when /\bgems\.rb\z/
        gemfile.sub_ext('.locked')
      else
        gemfile.sub_ext('.lock')
      end
    end

    def after_fork_callbacks
      @after_fork_callbacks ||= []
    end

    def after_fork(&block)
      after_fork_callbacks << block
    end

    def spawn_on_env
      @spawn_on_env ||= []
    end

    def reset_on_env
      @reset_on_env ||= []
    end

    def verify_environment
      application_root_path
    end

    def application_root_path
      @application_root_path ||= begin
        if application_root
          path = Pathname.new(File.expand_path(application_root))
        else
          path = project_root_path
        end

        raise MissingApplication.new(path) unless path.join("config/application.rb").exist?
        path
      end
    end

    def project_root_path
      @project_root_path ||= find_project_root(Pathname.new(File.expand_path(Dir.pwd)))
    end

    def quiet
      @quiet || ENV.key?('SPRING_QUIET')
    end

    private

    def find_project_root(current_dir)
      if current_dir.join(gemfile).exist?
        current_dir
      elsif current_dir.root?
        raise UnknownProject.new(Dir.pwd)
      else
        find_project_root(current_dir.parent)
      end
    end
  end

  self.quiet = false
end
