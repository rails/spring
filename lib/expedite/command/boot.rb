module Expedite
  module Command
    class Boot
      def call
        variant = ARGV[0]

        require "expedite/application"
        
        Expedite::Application.new(
          variant: variant,
          manager: UNIXSocket.for_fd(@child_socket.fileno),
          env: Expedite::Env.new(
            root: ENV['EXPEDITE_ROOT'],
            log_file: @log_file,
          ),
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
