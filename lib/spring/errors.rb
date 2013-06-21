module Spring
  class ClientError < StandardError; end

  class UnknownProject < StandardError
    attr_reader :current_dir

    def initialize(current_dir)
      @current_dir = current_dir
    end

    def message
      "Spring was unable to locate the root of your project. There was no Gemfile " \
        "present in the current directory (#{current_dir}) or any of the parent " \
        "directories."
    end
  end

  class TmpUnwritable < StandardError
    attr_reader :tmp_path

    def initialize(tmp_path)
      @tmp_path = tmp_path
    end

    def message
      "Spring is unable to create a socket file at #{tmp_path}. You may need to " \
        "set the SPRING_TMP_PATH environment variable to use a different path. See " \
        "the documentation for details."
    end
  end

  class MissingApplication < ClientError
    attr_reader :project_root

    def initialize(project_root)
      @project_root = project_root
    end

    def message
      "Spring was unable to find your config/application.rb file. " \
        "Your project root was detected at #{project_root}, so spring " \
        "looked for #{project_root}/config/application.rb but it doesn't exist. You can " \
        "configure the root of your application by setting Spring.application_root in " \
        "config/spring.rb."
    end
  end

  class CommandNotFound < ClientError
  end
end
