require "expedite/application"

app = Expedite::Application.new(
  ENV['EXPEDITE_VARIANT'],
  UNIXSocket.for_fd(3),
  {},
  Expedite::Env.new(log_file: IO.for_fd(4))
)
app.boot
