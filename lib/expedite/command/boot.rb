module Expedite
  module Command
    class Boot
      def call
        ENV['EXPEDITE_VARIANT'] = ARGV[0]

        # This is necessary for the terminal to work correctly when we reopen stdin.
        Process.setsid rescue Errno::EPERM

        require "expedite/application"

        app = Expedite::Application.new(
          UNIXSocket.for_fd(@child_socket.fileno),
          {},
          Expedite::Env.new(log_file: @log_file)
        )

        Signal.trap("TERM") { app.terminate }


        load "expedite_helper.rb" if File.exists?("expedite_helper.rb")

        app.eager_preload if false
        app.run
      end

      def exec_name
        "boot"
      end

      def setup(client)
        @child_socket = client.recv_io
        @log_file = client.recv_io
      end
    end
  end
end
