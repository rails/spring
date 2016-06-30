## 1.7.2

* Use `Spring.failsafe_thread` to prevent threads from aborting process due to `Thread.abort_on_exception` when set to `true`

## 1.7.1

* Specify absolute path to spring binfile when starting the server
  (#478)
* Time out after 10 seconds if starting the spring server doesn't work
  (maybe related to #480, #479)
* Prevent infinite boot loop when trying to restart the spring server
  due to client/server version mismatch (related to #479)

## 1.7.0

* Auto-restart server when server and client versions do not match
* Add `spring server` command to explicitly start a Spring server
  process in the foreground, which logging to stdout. This will be
  useful to those who want to run spring more explicitly, but the real
  impetus was to enable running a spring server inside a Docker
  container.
* Numerous other tweaks to better support running Spring inside
  containers (see
  https://github.com/jonleighton/spring-docker-example)

## 1.6.4

* Fix incompatibility with RubyGems 2.6.0.

## 1.6.3

* Fix problem with using Bundler 1.11 with a custom `BUNDLE_PATH` (#456)

## 1.6.2

* Fix problems with the implementation of the new "Running via Spring preloader"
  message (see #456, #457)
* Print "Running via Spring preloader" message to stderr, not stdout

## 1.6.1

* support replaced backtraces / backtraces with only line and number

## 1.6.0

* show when spring is used automatically to remind people why things might fail, disable with `Spring.quiet = true`

## 1.5.0

* Make the temporary directory path used by spring contain the UID of the process
  so that spring can work on machines where multiple users share a single $TMPDIR.

## 1.4.3

* Support new binstub format and --remove option

## 1.4.2

* Don't supress non-spring load errors in binstub

## 1.4.1

* Enable terminal resize detection in rails console.

## 1.4.0

* Add support for client side hooks. `config/spring_client.rb` is loaded before
  bundler and before a server process is started, it can be used to add new
  top-level commands.
* Do not boot up the server when using -h / --help

## 1.3.6

* Ensure the spawned server is loaded from the same version of the Spring gem
  as the client. Issue #295.

## 1.3.5

* Fix `rails test` command to run in test environment #403 - @eileencodes

## 1.3.4

* Add `rails test` command.

## 1.3.3

* Fix yet another problem with loading spring which seems to affect
  some/all rbenv users. Issue #390.

## 1.3.2

* Fix another problem with gems bundled from git repositories. This
  affected chruby and RVM users, and possibly others. See #383.

## 1.3.1

* Fix a problem with gems bundled from a git repository, where the
  `bin/spring` was generated before 1.3.0.

## 1.3.0

* Automatically restart spring after new commands are added. This means
  that you can add spring-commands-rspec to your Gemfile and then
  immediately start using it, without having to run `spring stop`.
  (Spring will effectively run `spring stop` for you.)
* Make app reloading work in apps which spew out lots of output on
  startup (previously a buffer would fill up and cause the process to
  hang). Issue #332.
* Make sure running `bin/spring` does not add an empty string to `Gem.path`.
  Issues #297, #310.
* Fixed problem with `$0` including the command line args, which could
  confuse commands which try to parse `$0`. This caused the
  spring-commands-rspec to not work properly in some cases. Issue #369.
* Add OpenBSD compatibility for `spring status`. Issue #299.
* Rails 3.2 no longer officially supported (but it may continue to work)

## 1.2.0

* Accept -e and --environment options for `rails console`.
* Watch `config/secrets.yml` by default. #289 - @morgoth
* Change monkey-patched `Kernel.raise` from public to private (to match default Ruby behavior) #351 - @mattbrictson
* Let application_id also respect RUBY_VERSION for the use case of switching between Ruby versions for a given Rails app - @methodmissing
* Extract the 'listen' watcher to a separate `spring-watcher-listen`
  gem. This allows it to be developed/maintained separately.

## 1.1.3

* The `rails runner` command no longer passes environment switches to
  files which it runs. Issue #272.
* Various issues solved to do with termination / processes hanging around
  longer than they should. Issue #290.

## 1.1.2

* Detect old binstubs generated with Spring 1.0 and exit with an error.
  This prevents a situation where you can get stuck in an infinite loop
  of spring invocations.
* Avoid `warning: already initialized constant APP_PATH` when running
  rails commands that do not use spring (e.g. `bin/rails server` would
  emit this when you ^C to exit)
* Fix `reload!` in rails console
* Don't connect/disconnect the database if there are no connections
  configured. Issue #256.

## 1.1.1

* Fix `$0` so that it is no longer prefixed with "spring ", as doing
  this cause issues with rspec when running just `rspec` with no
  arguments.
* Ensure we're always connected to a tty when preloading the
  application in the background, in order to avoid loading issues
  with readline + libedit which affected pry-rails.

## 1.1.0

* A `bin/spring` binstub is now generated. This allows us to load spring
  correctly if you have it installed locally with a `BUNDLE_PATH`, so
  it's no longer necessary to install spring system-wide. We also
  activate the correct version from your Gemfile.lock. Note that you
  still can't have spring in your Gemfile as a git repository or local
  path; it must be a proper gem.
* Various changes to how springified binstubs are implemented. Existing
  binstubs will continue to work, but it's recommended to run `spring binstub`
  again to upgrade them to the new format.
* `spring binstub --remove` option added for removing spring from
  binstubs. This won't work unless you have upgraded your binstubs to
  the new format.
* `config/database.yml` is watched
* Better application restarts - if you introduce an error, for example
  by editing `config/application.rb`, spring will now continue to watch
  your files and will immediately try to restart the application when
  you edit `config/application.rb` again (hopefully to correct the error).
  This means that by the time you come to run a command the application
  may well already be running.
* Gemfile changes are now gracefully handled. Previously they would
  cause spring to simply quit, meaning that you'd incur the full startup
  penalty on the next run. Now spring doesn't quit, and will try to load
  up your new bundle in the background.
* Fix support for using spring with Rails engines/plugins

## 1.0.0

* Enterprise ready secret sauce added

## 0.9.2

* Bugfix: environment variables set by bundler (`BUNDLE_GEMFILE`,
  `RUBYOPT`, etc...) were being removed from the environment.
* Ensure we only run the code reloader when files have actually changed.
  This issue became more prominent with Rails 4, since Rails 4 will now
  reload routes whenever the code is reloaded (see
  https://github.com/rails/rails/commit/b9b06daa915fdc4d11e8cfe11a7175e5cd8f104f).
* Allow spring to be used in a descendant directory of the application
  root
* Use the system tmpdir for our temporary files. Previously we used
  `APP_ROOT/tmp/spring`, which caused problems on filesystems which did
  not support sockets, and also caused problems if `APP_ROOT` was
  sufficiently deep in the filesystem to exhaust the operating system's
  socket name limit. Hence we had a `SPRING_TMP_PATH` environment
  variable for configuration. We now use `/tmp/spring/[md5(APP_ROOT)]`
  for the socket and `/tmp/spring/[md5(APP_ROOT)].pid` for the pid file.
  Thanks @Kriechi for the suggestion. Setting `SPRING_TMP_PATH` no longer
  has any effect.

## 0.9.1

* Environment variables which were created during application startup are no
  longer overwritten.
* Support for generating multiple binstubs at once. Use --all to
  generate all, otherwise you can pass multiple command names to the
  binstub command.
* The `testunit` command has been extracted to the
  `spring-commands-testunit` gem, because it's not necessary in Rails 4,
  where you can just run `rake test path/to/test`.
* The `~/.spring.rb` config file is loaded before bundler, so it's a good
  place to require extra commands which you want to use in all projects,
  without having to add those commands to the Gemfile of each individual
  project.
* Any gems in the bundle with names which start with "spring-commands-"
  are now autoloaded. This makes it less faffy to add additional
  commands.

## 0.9.0

* Display spring version in the help message
* Remove workaround for Rubygems performance issue. This issue is solved
  with Rubygems 2.1, so we no longer need to generate a "spring" binstub
  file. We warn users if they are not taking advantage of the Rubygems
  perf fix (e.g. if they are not on 2.1, or haven't run `gem pristine
  --all`). To upgrade, delete your `bin/spring` and re-run `spring
  binstub` for each of your binstubs.
* Binstubs now fall back to non-spring execution of a command if the
  spring gem is not present. This might be useful for production
  environments.
* The ENV will be replaced on each run to match the ENV which exists
  when the spring command is actually run (rather than the ENV which
  exists when spring first starts).
* Specifying the rails env after the rake command (e.g. `rake
  RAILS_ENV=test db:migrate`) now works as expected.
* Provide an explicit way to set the environment to use when running
  `rake` on its own.
* The `rspec` and `cucumber` commands are no longer shipped by default.
  They've been moved to the `spring-commands-rspec` and
  `spring-commands-cucumber` gems.

## 0.0.11

* Added the `rails destroy` command.
* Global config file in `~/.spring.rb`
* Added logging for debugging. Specify a log file with the
  `SPRING_LOG` environment variable.
* Fix hang on "Run `bundle install` to install missing gems"
* Added hack to make backtraces generated when running a command
  quieter (by stripping out all of the lines relating to spring)
* Rails 4 is officially supported

## 0.0.10

* Added `Spring.watch_method=` configuration option to switch between
  polling and the `listen` gem. Previously, we used the `listen` gem if
  it was available, but this makes the option explicit. Set
  `Spring.watch_method = :listen` to use the listen gem.
* Fallback when Process.fork is not available. In such cases, the user
  will not receive the speedup that Spring provides, but won't receive
  an error either.
* Don't preload `test_helper` or `spec_helper` by default. This was
  causing people subtle problems (for example see #113) and is perhaps
  surprising behaviour. It may be desirable but it depends on the
  application, therefore we suggest it to people in the README but no
  longer do it by default.
* Don't stay connected to database in the application processes. There's
  no need to keep a connection open.
* Avoid using the database in the application processes. Previously,
  reloading the autoloaded constants would inadvertantly cause a
  connection to the database, which would then prevent tasks like
  db:create from running (because at that point the database doesn't
  exist)
* Removed ability to specify list of files for a command to preload. We
  weren't using this any more internally, and this is easy to do by
  placing requires in suitable locations in the Rails boot process
  (which is not explained in the README).
* Seed the random number generator on each run.

## 0.0.9

* Added `Spring::Commands::Rake.environment_matchers` for matching
  rake tasks to specific environments.
* Kill the spring server when the `Gemfile` or `Gemfile.lock` is
  changed. This forces a new server to boot up on the next run, which
  ensures that you get the correct gems (or the correct error message from
  bundler if you have forgotten to `bundle install`.)
* Fixed error when `Spring.watch` is used in `config/spring.rb`

## 0.0.8

* Renamed `spring test` to `spring testunit`.
* Implemented `spring rails` to replace `spring
  [console|runner|generate]`.
* `config/spring.rb` is only loaded in the server process, so you can
  require stuff from other gems there without performance implications.
* File watcher no longer pays attention to files outside of your
  application root directory.
* You can use the `listen` gem for less CPU intensive file watching. See
  README.
