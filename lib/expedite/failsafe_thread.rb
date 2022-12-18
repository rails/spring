# Based on https://github.com/rails/spring/blob/master/lib/spring/failsafe_thread.rb
require 'thread'

module Expedite
  class << self
    def failsafe_thread
      Thread.new {
        begin
          yield
        rescue
        end
      }
    end
  end
end
