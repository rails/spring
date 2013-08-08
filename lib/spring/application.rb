require "set"
require "spring/watcher"

module Spring
  class Application
    attr_reader :manager, :watcher

    def initialize(manager, watcher = Spring.watcher)
      @manager = manager
      @watcher = watcher
      @setup   = Set.new

      # Workaround for GC bug in Ruby 2 which causes segfaults if watcher.to_io
      # instances get dereffed.
      @fds = [manager, watcher.to_io]
    end

    def start
      require Spring.application_root_path.join("config", "application")

      # config/environments/test.rb will have config.cache_classes = true. However
      # we want it to be false so that we can reload files. This is a hack to
      # override the effect of config.cache_classes = true. We can then actually
      # set config.cache_classes = false after loading the environment.
      Rails::Application.initializer :initialize_dependency_mechanism, group: :all do
        ActiveSupport::Dependencies.mechanism = :load
      end

      require Spring.application_root_path.join("config", "environment")

      Rails.application.config.cache_classes = false
      disconnect_database

      watcher.add loaded_application_features
      watcher.add Spring.gemfile, "#{Spring.gemfile}.lock"
      watcher.add Rails.application.paths["config/initializers"]

      run
    end

    def run
      watcher.start

      loop do
        IO.select(@fds)

        if watcher.stale?
          exit
        else
          serve manager.recv_io(UNIXSocket)
        end
      end
    end

    def serve(client)
      manager.puts

      streams = 3.times.map { client.recv_io }
      args    = JSON.load(client.read(client.gets.to_i))
      command = Spring.command(args.shift)

      connect_database
      setup command

      ActionDispatch::Reloader.cleanup!
      ActionDispatch::Reloader.prepare!

      pid = fork {
        Process.setsid
        [STDOUT, STDERR, STDIN].zip(streams).each { |a, b| a.reopen(b) }
        IGNORE_SIGNALS.each { |sig| trap(sig, "DEFAULT") }

        connect_database
        ARGV.replace(args)
        srand

        invoke_after_fork_callbacks

        if command.respond_to?(:call)
          command.call
        else
          exec_name = command.exec_name
          gem_name  = command.gem_name if command.respond_to?(:gem_name)

          exec = Gem.bin_path(gem_name || exec_name, exec_name)
          $0 = exec
          load exec
        end
      }

      disconnect_database

      manager.puts pid

      # Wait in a separate thread so we can run multiple commands at once
      Thread.new {
        _, status = Process.wait2 pid
        streams.each(&:close)
        client.puts(status.exitstatus)
        client.close
      }

    rescue => e
      streams.each(&:close) if streams
      client.puts(1)
      client.close
      raise
    end

    # The command might need to require some files in the
    # main process so that they are cached. For example a test command wants to
    # load the helper file once and have it cached.
    def setup(command)
      return if @setup.include?(command.class)
      @setup << command.class

      if command.respond_to?(:setup)
        command.setup
        watcher.add loaded_application_features # loaded features may have changed
      end
    end

    def invoke_after_fork_callbacks
      Spring.after_fork_callbacks.each do |callback|
        callback.call
      end
    end

    def loaded_application_features
      $LOADED_FEATURES.select { |f| f.start_with?(File.realpath(Rails.root)) }
    end

    def disconnect_database
      ActiveRecord::Base.remove_connection if defined?(ActiveRecord::Base)
    end

    def connect_database
      ActiveRecord::Base.establish_connection if defined?(ActiveRecord::Base)
    end
  end
end
