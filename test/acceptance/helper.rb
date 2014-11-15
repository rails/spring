require "spring/env"

module Spring
  module Test
    class RailsVersion
      attr_reader :version

      def initialize(string)
        @version = Gem::Version.new(string)
      end

      def rails_3?
        version < Gem::Version.new("4.0.0")
      end
      alias needs_testunit? rails_3?

      def test_command
        needs_testunit? ? 'bin/testunit' : 'bin/rake test'
      end

      def controller_tests_dir
        rails_3? ? 'functional' : 'controllers'
      end

      def bundles_spring?
        version.segments.take(2) == [4, 1] || version > Gem::Version.new("4.1")
      end

      def major
        version.segments[0]
      end

      def minor
        version.segments[1]
      end

      def to_s
        version.to_s
      end
    end

    class Application
      DEFAULT_TIMEOUT = ENV['CI'] ? 30 : 10

      attr_reader :root, :spring_env

      def initialize(root)
        @root       = Pathname.new(root)
        @spring_env = Spring::Env.new(root)
      end

      def exists?
        root.exist?
      end

      def stdout
        @stdout ||= IO.pipe
      end

      def stderr
        @stderr ||= IO.pipe
      end

      def log_file
        @log_file ||= path("tmp/spring.log").open("w+")
      end

      def env
        @env ||= {
          "GEM_HOME"   => gem_home.to_s,
          "GEM_PATH"   => gem_home.to_s,
          "HOME"       => user_home.to_s,
          "RAILS_ENV"  => nil,
          "RACK_ENV"   => nil,
          "SPRING_LOG" => log_file.path
        }
      end

      def path(addition)
        root.join addition
      end

      def gemfile
        path "Gemfile"
      end

      def gem_home
        path "vendor/gems/#{RUBY_VERSION}"
      end

      def user_home
        path "user_home"
      end

      def spring
        gem_home.join "bin/spring"
      end

      def rails_version
        @rails_version ||= RailsVersion.new(gemfile.read.match(/gem 'rails', '(.*)'/)[1])
      end

      def spring_test_command
        "#{rails_version.test_command} #{test}"
      end

      def stop_spring
        run "#{spring} stop"
      rescue Errno::ENOENT
      end

      def test
        path "test/#{rails_version.controller_tests_dir}/posts_controller_test.rb"
      end

      def controller
        path "app/controllers/posts_controller.rb"
      end

      def application_config
        path "config/application.rb"
      end

      def spring_config
        path "config/spring.rb"
      end

      def run(command, opts = {})
        start_time = Time.now

        Bundler.with_clean_env do
          Process.spawn(
            env.merge(opts.fetch(:env, {})),
            command.to_s,
            out:   stdout.last,
            err:   stderr.last,
            in:    :close,
            chdir: root.to_s,
          )
        end

        max_time = opts.fetch(:timeout, DEFAULT_TIMEOUT)
        _, status = Timeout.timeout(max_time) { Process.wait2 }

        if pid = spring_env.pid
          @server_pid = pid
          lines = `ps -A -o ppid= -o pid= | egrep '^\\s*#{@server_pid}'`.lines
          @application_pids = lines.map { |l| l.split.last.to_i }
        end

        output = read_streams
        puts dump_streams(command, output) if ENV["SPRING_DEBUG"]

        @times << (Time.now - start_time) if @times

        output.merge(status: status, command: command)
      rescue Timeout::Error => e
        raise "#{e.to_s}: Output:\n\n#{dump_streams(command, read_streams)} \n(command took more than #{max_time} seconds)"
      end

      def with_timing
        @times = []
        yield
      ensure
        @times = nil
      end

      def last_time
        @times.last
      end

      def first_time
        @times.first
      end

      def timing_ratio
        last_time / first_time
      end

      def read_streams
        {
          stdout: read_stream(stdout.first),
          stderr: read_stream(stderr.first),
          log:    read_stream(log_file)
        }
      end

      def read_stream(stream)
        output = ""
        while IO.select([stream], [], [], 0.5) && !stream.eof?
          output << stream.readpartial(10240)
        end
        output
      end

      def prefix(line)
        "  >#{line}"
      end

      def dump_streams(command, streams)
        output = prefix("$ #{command}\n")

        streams.each do |name, stream|
          unless stream.chomp.empty?
            output << prefix("--- #{name} ---\n")
            stream.lines.each do |line|
              output << prefix("#{line.chomp}\n")
            end
          end
        end

        output << "\n"
        output
      end

      def debug(artifacts)
        artifacts = artifacts.dup
        artifacts.delete :status
        dump_streams(artifacts.delete(:command), artifacts)
      end

      def await_reload
        raise "no pid" if @application_pids.nil? || @application_pids.empty?

        Timeout.timeout(DEFAULT_TIMEOUT) do
          sleep 0.1 while @application_pids.any? { |p| process_alive?(p) }
        end
      end

      def run!(command, options = {})
        attempts  = (options.delete(:retry) || 0) + 1
        artifacts = nil

        until attempts == 0 || artifacts && artifacts[:status].success?
          artifacts = run(command, options)
          attempts -= 1
        end

        if artifacts[:status].success?
          artifacts
        else
          raise "command failed\n\n#{debug(artifacts)}"
        end
      end

      def bundle
        run! "(gem list bundler | grep bundler) || gem install --no-ri --no-rdoc bundler", timeout: nil, retry: 2
        run! "bundle check || bundle update --retry=2", timeout: nil
      end

      private

      def process_alive?(pid)
        Process.kill 0, pid
        true
      rescue Errno::ESRCH
        false
      end
    end

    class ApplicationGenerator
      attr_reader :version_constraint, :version, :application

      def initialize(version_constraint)
        @version_constraint = version_constraint
        @version            = RailsVersion.new(version_constraint.split(' ').last)
        @application        = Application.new(root)
        @bundled            = false
      end

      def root
        "#{TEST_ROOT}/apps/rails-#{version.major}-#{version.minor}-spring-#{Spring::VERSION}"
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

        application.run! "bundle exec rails g scaffold post title:string", env: {'DISABLE_SPRING' => '1'}
        application.run! "bundle exec rake db:migrate db:test:clone", env: {'DISABLE_SPRING' => '1'}
      end

      def generate_if_missing
        generate unless application.exists?
      end

      def install_spring
        return if @installed

        system("gem build spring.gemspec 2>&1")
        application.run! "gem install --no-ri --no-rdoc ../../../spring-#{Spring::VERSION}.gem", timeout: nil

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
