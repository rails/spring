# This is necessary for the terminal to work correctly when we reopen stdin.
Process.setsid

require "spring/application"
Spring.project_root_path.join('.spring.rb').tap do |config|
  require config if config.exist?
end

app = Spring::Application.new(
  UNIXSocket.for_fd(3),
  Spring::JSON.load(ENV.delete("SPRING_ORIGINAL_ENV").dup)
)

Signal.trap("TERM") { app.terminate }

Spring::ProcessTitleUpdater.run { |distance|
  "spring app    | #{app.app_name} | started #{distance} ago | #{app.app_env} mode"
}

app.eager_preload if ENV.delete("SPRING_PRELOAD") == "1"
app.run
