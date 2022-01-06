require 'json'

module Expedite
  module SendJson
    def send_json(socket, data)
      data = Marshal.dump(data)

      socket.puts  data.bytesize
      socket.write data
    end

    def read_json(socket)
      Marshal.load(socket.read(socket.gets.to_i))
    end
  end
end
