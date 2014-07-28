module Spring
  module Test
    class ApplicationGenerator
      attr_reader :version_constraint, :version, :application

      def initialize(version_constraint)
        @version_constraint = version_constraint
        @version            = RailsVersion.new(version_constraint.split(' ').last)
        @application        = Application.new(root)
        @bundled            = false
      end

      def root
        "#{Spring::Test.root}/apps/rails-#{version.major}-#{version.minor}-spring-#{Spring::VERSION}"
      end

      def system(command)
        if ENV["SPRING_DEBUG"]
          puts "$ #{command}\n"
        else
          command = "(#{command}) > /dev/null"
        end

        Kernel.system(command) or raise "command failed: #{command}"
        puts if ENV["SPRING_DEBUG"]
      end

      # Sporadic SSL errors keep causing test failures so there are anti-SSL workarounds here
      def generate
        Bundler.with_clean_env do
          system("gem list rails --installed --version '#{version_constraint}' || " \
                   "gem install rails --clear-sources --source http://rubygems.org --version '#{version_constraint}'")

          @version = RailsVersion.new(`ruby -e 'puts Gem::Specification.find_by_name("rails", "#{version_constraint}").version'`.chomp)

          skips = %w(--skip-bundle --skip-javascript --skip-sprockets)
          skips << "--skip-spring" if version.bundles_spring?

          system("rails _#{version}_ new #{application.root} #{skips.join(' ')}")
          raise "application generation failed" unless application.exists?

          FileUtils.mkdir_p(application.gem_home)
          FileUtils.mkdir_p(application.user_home)
          FileUtils.rm_rf(application.path("test/performance"))

          File.write(application.gemfile, "#{application.gemfile.read}gem 'spring', '#{Spring::VERSION}'\n")

          if version.needs_testunit?
            File.write(application.gemfile, "#{application.gemfile.read}gem 'spring-commands-testunit'\n")
          end

          File.write(application.gemfile, application.gemfile.read.sub("https://rubygems.org", "http://rubygems.org"))

          if application.path("bin").exist?
            FileUtils.cp_r(application.path("bin"), application.path("bin_original"))
          end
        end

        install_spring

        application.run! "bundle exec rails g scaffold post title:string"
        application.run! "bundle exec rake db:migrate db:test:clone"
      end

      def generate_if_missing
        generate unless application.exists?
      end

      def install_spring
        return if @installed

        system("gem build spring.gemspec 2>&1")
        application.run! "gem install ../../../spring-#{Spring::VERSION}.gem", timeout: nil

        application.bundle

        FileUtils.rm_rf application.path("bin")

        if application.path("bin_original").exist?
          FileUtils.cp_r application.path("bin_original"), application.path("bin")
        end

        application.run! "#{application.spring} binstub --all"
        @installed = true
      end

      def copy_to(path)
        system("rm -rf #{path}")
        system("cp -r #{application.root} #{path}")
      end
    end
  end
end
