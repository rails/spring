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
