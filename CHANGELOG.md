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
