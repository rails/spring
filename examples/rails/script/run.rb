#!/usr/bin/env ruby
require 'expedite'

ret = Expedite.v("development/abc").invoke("runner", ARGV)
puts "ret = #{ret}"

begin
  ret = Expedite.v("development/abc").invoke("raise")
  puts "ret = #{ret}"
rescue => e
  puts "#{e}: #{e.backtrace.join("\n")}"
end

ret = Expedite.v("development/abc").exec("runner", ARGV)
# never reaches here
puts "ret = #{ret}"
