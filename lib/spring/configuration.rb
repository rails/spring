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

    # Callbacks invoked once on the spring server, after config/environment
    # has finished loading and Rails autoloads are wired up. Use this to
    # preload heavy test/dev support files that depend on Rails being ready,
    # so the forked child doesn't pay the cost on every command.
    def after_environment_load_callbacks
      @after_environment_load_callbacks ||= []
    end

    def after_environment_load(&block)
      after_environment_load_callbacks << block
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
