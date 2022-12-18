# Based on https://github.com/rails/spring/blob/master/lib/spring/application/boot.rb

# This is necessary for the terminal to work correctly when we reopen stdin.
Process.setsid rescue Errno::EPERM

require "expedite/application"

app = Expedite::Application.new(
  UNIXSocket.for_fd(3),
  {},
  Expedite::Env.new(log_file: IO.for_fd(4))
)

Signal.trap("TERM") { app.terminate }

load "expedite_helper.rb" if File.exists?("expedite_helper.rb")

app.eager_preload if false #if ENV.delete("SPRING_PRELOAD") == "1"
app.run
