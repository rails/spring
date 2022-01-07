require 'socket'

module Expedite
  module Protocol
    def send_object(object)
      data = Marshal.dump(object)

      self.puts  data.bytesize
      self.write data
    end

    def recv_object
      Marshal.load(self.read(self.gets.to_i))
    end
  end
end

UNIXSocket.include ::Expedite::Protocol
