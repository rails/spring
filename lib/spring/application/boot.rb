# This is necessary for the terminal to work correctly when we reopen stdin.
Process.setsid

require "spring/application"

remote_socket =
  if ENV["SPRING_SOCKET"]
    UNIXSocket.open(ENV.delete("SPRING_SOCKET"))
  else
    UNIXSocket.for_fd(3)
  end

app = Spring::Application.create(
  remote_socket,
  Spring::JSON.load(ENV.delete("SPRING_ORIGINAL_ENV").dup)
)

Signal.trap("TERM") { app.terminate }

Spring::ProcessTitleUpdater.run { |distance|
  "spring app    | #{app.app_name} | started #{distance} ago | #{app.app_env} mode"
}

app.eager_preload if ENV.delete("SPRING_PRELOAD") == "1"
app.run
