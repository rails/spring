module Expedite
  module SendJson
    def send_json(socket, data)
      data = JSON.dump(data)

      socket.puts  data.bytesize
      socket.write data
    end
  end
end
