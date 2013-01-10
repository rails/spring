require "spring/application_watcher"
require "spring/commands"
require "set"

class Spring
  class << self
    attr_accessor :application_watcher
  end

  self.application_watcher = ApplicationWatcher.new

  class Application
    WATCH_INTERVAL = 0.2

    attr_reader :manager, :watcher

    def initialize(manager, watcher = Spring.application_watcher)
      @manager = manager
      @watcher = watcher
      @setup   = Set.new

      @stdout = IO.new(STDOUT.fileno)
      @stderr = IO.new(STDERR.fileno)
      @stdin  = IO.new(STDIN.fileno)
    end

    def start
      require "./config/application"

      # The test environment has config.cache_classes = true set by default.
      # However, we don't want this to prevent us from performing class reloading,
      # so this gets around that.
      Rails::Application.initializer :initialize_dependency_mechanism, group: :all do
        ActiveSupport::Dependencies.mechanism = :load
      end

      require "./config/environment"

      watcher.add_files $LOADED_FEATURES
      watcher.add_files ["Gemfile", "Gemfile.lock"].map { |f| "#{Rails.root}/#{f}" }
      watcher.add_globs Rails.application.paths["config/initializers"].map { |p| "#{Rails.root}/#{p}/*.rb" }
    end

    def run
      loop do
        watch_application
        serve manager.recv_io(UNIXSocket)
      end
    end

    def watch_application
      until IO.select([manager], [], [], WATCH_INTERVAL)
        exit if watcher.stale?
      end
    end

    def serve(client)
      client.puts
      redirect_output(client) do
        args_length = client.gets.to_i
        args        = args_length.times.map { client.read(client.gets.to_i) }
        command     = Spring.command(args.shift)

        setup command

        ActionDispatch::Reloader.cleanup!
        ActionDispatch::Reloader.prepare!

        Process.wait(fork { command.call(args) })
      end
    ensure
      client.puts
      client.close
    end

    # The command might need to require some files in the
    # main process so that they are cached. For example a test command wants to
    # load the helper file once and have it cached.
    #
    # FIXME: The watcher.add_files will reset the watcher, which may mean that
    #        previous changes to already-loaded files are missed.
    def setup(command)
      return if @setup.include?(command.class)
      @setup << command.class

      if command.respond_to?(:setup)
        command.setup
        watcher.add_files $LOADED_FEATURES # loaded features may have changed
      end
    end

    def redirect_output(socket)
      STDOUT.reopen socket.recv_io
      STDERR.reopen socket.recv_io
      STDIN.reopen  socket.recv_io

      yield
    ensure
      STDOUT.reopen @stdout
      STDERR.reopen @stderr
      STDIN.reopen  @stdin
    end
  end
end
