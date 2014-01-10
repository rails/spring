require "spring/application"

app = Spring::Application.new(
  UNIXSocket.for_fd(3),
  Spring::JSON.load(ENV.delete("SPRING_ORIGINAL_ENV").dup)
)
Signal.trap("TERM") { app.terminate }

app.preload if ENV.delete("SPRING_PRELOAD") == "1"
app.run
