module Spring
  class InvalidEnvironmentError < StandardError; end

  class MissingProjectRootError < InvalidEnvironmentError
    def initialize(current_dir)
      super <<-MSG
Spring was not able to locate the root of your project.
You should:
  - make sure that you are inside a rails application.

Spring used the following paths to detect the project root (`Gemfile`):
  pwd: #{current_dir}
MSG
    end
  end

  class MissingApplicationRoot < InvalidEnvironmentError
    def initialize(current_dir, project_root)
      super <<-MSG
Spring was not able to locate the rails root of your project.
You should:
  - change your working directory.
  - configure the location of your rails application using `config/spring.rb`.

Spring used the following paths to detect the Rails root (`config/application.rb`):
  pwd: #{current_dir}
  project root: #{project_root}
MSG
    end
  end
end
