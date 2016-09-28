command  = File.basename($0)
bin_path = File.expand_path("../../../bin/spring", __FILE__)

# When we run a command which does not go through Spring (e.g. DISABLE_SPRING
# is used, or we just call 'rails' or something) then we get this warning from
# Rubygems:
#
#   WARN: Unresolved specs during Gem::Specification.reset: activesupport (<= 5.1, >= 4.2)
#   WARN: Clearing out unresolved specs.
#   Please report a bug if this causes problems.
#
# This happens due to our dependency on activesupport, when Bundler.setup gets
# called.  We don't actually *use* the dependency; it is purely there to
# restrict the Rails version that we're compatible with.
#
# When the warning is shown, Rubygems just does the below.
# Therefore, by doing it ourselves here, we can avoid the warning.
if Gem::Specification.respond_to?(:unresolved_deps)
  Gem::Specification.unresolved_deps.clear
else
  Gem.unresolved_deps.clear
end

if command == "spring"
  load bin_path
else
  disable = ENV["DISABLE_SPRING"]

  if Process.respond_to?(:fork) && (disable.nil? || disable.empty? || disable == "0")
    ARGV.unshift(command)
    load bin_path
  end
end
