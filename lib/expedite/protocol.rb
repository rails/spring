require 'socket'

module Expedite
  module Protocol
    def send_object(object)
      data = Marshal.dump(object)

      self.puts  data.bytesize.to_i
      self.write data
    end

    def recv_object
      len = self.gets.to_i
      data = self.read(len)
      Marshal.load(data)
    end
  end
end

IO.include ::Expedite::Protocol
