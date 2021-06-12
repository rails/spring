module Expedite
  module Command
    class Boot
      def call
        variant = ARGV[0]

        require "expedite/application"
        
        Expedite::Application.new(
          variant,
          UNIXSocket.for_fd(@child_socket.fileno),
          {},
          Expedite::Env.new(log_file: @log_file)
        ).boot
      end

      def setup(client)
        @child_socket = client.recv_io
        @log_file = client.recv_io
      end

      def runs_in
        :server
      end
    end
  end
end

Expedite::Commands.register("expedite/boot", Expedite::Command::Boot)