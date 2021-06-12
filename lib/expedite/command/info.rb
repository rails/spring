module Expedite
  module Command
    class Info
      def call
        puts "1"
        client.puts
        puts "2"
        unix_socket = UNIXSocket.for_fd(app_client.fileno)
        _stdout, stderr, _stdin = streams = 3.times.map do
          puts "4"
          unix_socket.recv_io
        end
        puts "5"
        client.puts Process.pid
        puts "6"
        unix_socket.puts 11 #application_pids.to_json
        puts "7"
        unix_socket.puts 10
        puts "8"
        unix_socket.close
        client.close

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

Expedite::Commands.register("expedite/info", Expedite::Command::Info)
