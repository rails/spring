command = File.basename($0)

if command == "spring"
  load Gem.bin_path("spring", "spring")
else
  disable = ENV["DISABLE_SPRING"]

  if Process.respond_to?(:fork) && (disable.nil? || disable.empty? || disable == "0")
    ARGV.unshift(command)
    load Gem.bin_path("spring", "spring")
  end
end
