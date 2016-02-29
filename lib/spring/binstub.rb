require 'rbconfig'

command  = File.basename($0)
bin_path = File.expand_path("../../../bin/spring", __FILE__)

if command == "spring"
  load bin_path
else
  disable = ENV["DISABLE_SPRING"]
  not_windows = !(RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)

  if not_windows && (disable.nil? || disable.empty? || disable == "0")
    ARGV.unshift(command)
    load bin_path
  end
end
