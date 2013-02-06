require "spring/errors"

module Spring
  class << self
    attr_accessor :application_root

    def verify_environment!
      application_root_path
    end

    def application_root_path
      return @application_root_path if defined?(@application_root_path)
      path = application_root || detect_application_root
      @application_root_path = Pathname.new(File.expand_path(path))
    end

    private

    def detect_application_root
      project_root = detect_project_root
      if File.exist?(project_root.join "config", "application.rb")
        project_root
      else
        raise MissingApplicationRoot.new(Dir.pwd, project_root)
      end
    end

    def detect_project_root(current_dir = Pathname.new(Dir.pwd))
      if File.exist?(current_dir.join "Gemfile")
        current_dir
      elsif current_dir.root?
        raise MissingProjectRootError.new(Dir.pwd)
      else
        detect_project_root(current_dir.parent)
      end
    end
  end

end
