require "spring/application"

app = Spring::Application.new(
  UNIXSocket.for_fd(3),
  Spring::JSON.load(ENV.delete("SPRING_ORIGINAL_ENV").dup)
)

Signal.trap("TERM") { app.terminate }
Signal.trap("TTOU", "IGNORE")

Spring::ProcessTitleUpdater.run { |distance|
  "spring app    | #{app.app_name} | started #{distance} ago | #{app.app_env} mode"
}

app.preload if ENV.delete("SPRING_PRELOAD") == "1"
app.run
