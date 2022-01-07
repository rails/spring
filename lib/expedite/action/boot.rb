module Expedite
  module Action
    class Boot
      def call(*args)
        agent = args[0]

        require "expedite/server/agent"
        
        Expedite::Server::Agent.new(
          agent: agent,
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
