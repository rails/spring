#!/usr/bin/env ruby
require 'expedite'

label = "[#{Process.pid}] run.rb"

ret = Expedite.agent("development/abc").invoke("runner", ARGV)
puts "#{label}: Invoked runner on development/abc, got #{ret}"

begin
  ret = Expedite.agent("development/abc").invoke("raise")
  puts "#{label}: We never reach here"
rescue => e
  puts "#{label}: Invoked raise on development/abc, caught: #{e}\n  #{e.backtrace.join("\n  ")}"
end

puts "#{label}: Exec runner on development/abc. Process will be replaced..."
Expedite.agent("development/abc").exec("runner", ARGV)
puts "#{label}: We never reach here"
