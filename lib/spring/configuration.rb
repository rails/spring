require "spring/errors"

module Spring
  class << self
    attr_accessor :application_root

    def after_fork_callbacks
      @after_fork_callbacks ||= []
    end

    def after_fork(&block)
      after_fork_callbacks << block
    end

    def verify_environment!
      application_root_path
    end

    def application_root_path
      @application_root_path ||= begin
        path = Pathname.new(File.expand_path(application_root || find_project_root))
        raise MissingApplication.new(path) unless path.join("config/application.rb").exist?
        path
      end
    end

    private

    def find_project_root(current_dir = Pathname.new(Dir.pwd))
      if current_dir.join("Gemfile").exist?
        current_dir
      elsif current_dir.root?
        raise UnknownProject.new(Dir.pwd)
      else
        find_project_root(current_dir.parent)
      end
    end
  end
end
