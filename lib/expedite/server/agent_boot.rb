require "expedite/server/agent"

app = Expedite::Server::Agent.new(
  agent: ENV['EXPEDITE_VARIANT'],
  manager: UNIXSocket.for_fd(3),
  env: Expedite::Env.new(
    root: ENV['EXPEDITE_ROOT'],
    log_file: IO.for_fd(4),
  ),
)
app.boot
