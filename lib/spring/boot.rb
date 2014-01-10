require "socket"
require "thread"

require "spring/configuration"
require "spring/env"
require "spring/application_manager"
require "spring/process_title_updater"
require "spring/json"

# Must be last, as it requires bundler/setup
require "spring/commands"

# readline must be required before we setpgid, otherwise the require may hang,
# if readline has been built against libedit. See issue #70.
require "readline"
