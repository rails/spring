command = File.basename($0)
ARGV.unshift(command) unless command == "spring"

if Process.respond_to?(:fork)
  load Gem.bin_path("spring", "spring")
end
