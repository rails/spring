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
