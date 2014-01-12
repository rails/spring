require "socket"
require "thread"

# readline must be required before we setpgid, otherwise the require may hang,
# if readline has been built against libedit. See issue #70.
require "readline"

require "spring/configuration"
require "spring/env"
require "spring/process_title_updater"
require "spring/json"
require "spring/watcher"
