require "spring/configuration"
require "spring/watcher"
require "spring/commands"
require "set"

module Spring
  class Application
    attr_reader :manager, :watcher

    def initialize(manager, watcher = Spring.watcher)
      @manager = manager
      @watcher = watcher
      @setup   = Set.new
    end

    def start
      require Spring.application_root_path.join("config", "application")

      # The test environment has config.cache_classes = true set by default.
      # However, we don't want this to prevent us from performing class reloading,
      # so this gets around that.
      Rails::Application.initializer :initialize_dependency_mechanism, group: :all do
        ActiveSupport::Dependencies.mechanism = :load
      end

      require Spring.application_root_path.join("config", "environment")

      watcher.add loaded_application_features
      watcher.add "Gemfile", "Gemfile.lock"
      watcher.add Rails.application.paths["config/initializers"]

      run
    end

    def run
      watcher.start

      loop do
        IO.select([manager, watcher])

        if watcher.stale?
          exit
        else
          serve manager.recv_io(UNIXSocket)
        end
      end
    end

    def serve(client)
      streams     = 3.times.map { client.recv_io }
      args_length = client.gets.to_i
      args        = args_length.times.map { client.read(client.gets.to_i) }
      command     = Spring.command(args.shift)

      setup command

      ActionDispatch::Reloader.cleanup!
      ActionDispatch::Reloader.prepare!

      pid = fork {
        Process.setsid
        [STDOUT, STDERR, STDIN].zip(streams).each { |a, b| a.reopen(b) }
        IGNORE_SIGNALS.each { |sig| trap(sig, "DEFAULT") }
        ActiveRecord::Base.establish_connection if defined?(ActiveRecord::Base)
        invoke_after_fork_callbacks
        command.call(args)
      }

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

      ActiveRecord::Base.connection.disconnect! if defined?(ActiveRecord::Base)
    end

    def invoke_after_fork_callbacks
      Spring.after_fork_callbacks.each do |callback|
        callback.call
      end
    end

    def loaded_application_features
      $LOADED_FEATURES.select { |f| f.start_with?(File.realpath(Rails.root)) }
    end
  end
end
