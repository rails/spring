# Spring

[![Build Status](https://travis-ci.org/jonleighton/spring.png?branch=master)](https://travis-ci.org/jonleighton/spring)

Spring is a Rails application preloader. It's trying to solve the same
problem as [spork](https://github.com/sporkrb/spork),
[zeus](https://github.com/burke/zeus) and
[commands](https://github.com/rails/commands).

## Features

Spring is most similar to Zeus, but it's implemented in pure Ruby, and
is more tightly integrated with Rails (it makes use of Rails' built-in
code reloader).

Spring tries to be totally automatic.
It boots up in the background the first time you run a
command. Then it speeds up subsequent commands. If it detects that your
pre-loaded environment has changed (maybe `config/application.rb` has
been edited) then it will reload your environment in the background,
ready for the next command. When you close your terminal session, Spring
will automatically shut down. There's no "server" to manually start and
stop.

Spring operates via a command line interface. Other solutions (e.g.
commands) take the approach of using a special console to run commands
from. This means we will have to re-implement shell features such as
history, completion, etc. Whilst it's not impossible to re-implement
those features, it's unnecessary work and our re-implementation
won't be as feature complete as a real shell. Using a real shell also
prevents the user having to constantly jump between a terminal with a
real shell and a terminal running the rails "commands console".

## Compatibility

Ruby versions supported:

* MRI 1.9.3
* MRI 2.0.0

Rails versions supported:

* 3.2
* 4.0

Spring makes extensive use of `Process#fork`, so won't be able to run on
any platform which doesn't support that (Windows, JRuby).

## Usage

Install the `spring` gem. You can add it to your Gemfile if you like but
it's optional. You now have a `spring` command. Don't use it with
`bundle exec` or it will be extremely slow.

For this walkthrough, I'm using the test app in the Spring repository:

```
cd /path/to/spring/test/apps/rails-3-2
```

We can run a test:

```
$ time spring testunit test/functional/posts_controller_test.rb
Run options:

# Running tests:

.......

Finished tests in 0.127245s, 55.0121 tests/s, 78.5887 assertions/s.

7 tests, 10 assertions, 0 failures, 0 errors, 0 skips

real    0m2.165s
user    0m0.281s
sys     0m0.066s
```

That booted our app in the background:

```
$ spring status
Spring is running:

26150 spring server | rails-3-2 | started 3 secs ago
26155 spring app    | rails-3-2 | started 3 secs ago | test mode
```

We can see two processes, one is the Spring server, the other is the
application running in the test environment. When we close the terminal,
the processes will be killed automatically.

Running the test is faster next time:

```
$ time spring testunit test/functional/posts_controller_test.rb
Run options:

# Running tests:

.......

Finished tests in 0.176896s, 39.5714 tests/s, 56.5305 assertions/s.

7 tests, 10 assertions, 0 failures, 0 errors, 0 skips

real    0m0.610s
user    0m0.276s
sys     0m0.059s
```

Running `spring testunit`, `spring rake`, `spring rails`, etc gets a bit
tedious. It also suffers from a performance issue in Rubygems ([which I
am actively working on](https://github.com/rubygems/rubygems/pull/435))
which means the `spring` command takes a while to start up. The more
gems you have, the longer it takes.

Spring binstubs solve both of these problems. If you will be running the
`testunit` command regularly, run:

```
$ spring binstub testunit
```

This generates a `bin/spring` and a `bin/testunit`, which allows you to run
`spring` and `spring testunit` in a way that doesn't trigger the Rubygems
performance bug:

```
$ time bin/testunit test/functional/posts_controller_test.rb
Run options:

# Running tests:

.......

Finished tests in 0.166585s, 42.0207 tests/s, 60.0296 assertions/s.

7 tests, 10 assertions, 0 failures, 0 errors, 0 skips

real    0m0.407s
user    0m0.077s
sys     0m0.059s
```

You can add "./bin" to your `PATH` when in your application's directory
[with direnv](https://github.com/zimbatm/direnv), but you should
recognise and understand the security implications of using that.

Note: Don't use spring binstubs with `bundle install --binstubs`.  If
you do this, spring and bundler will overwrite each other. If _you will_
not be using a command with spring, use `bundle binstub [GEM]` to
generate a bundler binstub for that specific gem.  If you _will_ be
using a command with spring, generate a spring binstub _instead of_ a
bundler binstub; spring will run your command inside the bundle anyway.

If we edit any of the application files, or test files, the change will
be picked up on the next run, without the background process
having to be restarted.

If we edit any of the preloaded files, the application needs to restart
automatically. Let's "edit" `config/application.rb`:

```
$ touch config/application.rb
$ spring status
Spring is running:

26150 spring server | rails-3-2 | started 36 secs ago
26556 spring app    | rails-3-2 | started 1 sec ago | test mode
```

The application process detected the change and exited. The server process
then detected that the application process exited, so it started a new application.
All of this happened automatically. Next time we run a
command we'll be running against a fresh application. We can see that
the start time and PID of the app process has changed.

If we run a command that uses a different environment, then it gets
booted up. For example, the `rake` command uses the `development`
environment by default:

```
$ spring binstub rake
$ bin/rake routes
    posts GET    /posts(.:format)          posts#index
          POST   /posts(.:format)          posts#create
 new_post GET    /posts/new(.:format)      posts#new
edit_post GET    /posts/:id/edit(.:format) posts#edit
     post GET    /posts/:id(.:format)      posts#show
          PUT    /posts/:id(.:format)      posts#update
          DELETE /posts/:id(.:format)      posts#destroy
```

We now have 3 processes: the server, and application in test mode and
the application in development mode.

```
$ bin/spring status
Spring is running:

26150 spring server | rails-3-2 | started 1 min ago
26556 spring app    | rails-3-2 | started 42 secs ago | test mode
26707 spring app    | rails-3-2 | started 2 secs ago | development mode
```

To stop the background processes:

```
$ bin/spring stop
Spring stopped.
```

## Commands

The following commands are shipped by default.

Custom commands can be specified in the Spring config file. See
[`lib/spring/commands.rb`](https://github.com/jonleighton/spring/blob/master/lib/spring/commands.rb)
for examples.

A bunch of different test frameworks are supported at the moment in
order to make it easy for people to try spring. However in the future
the code to use a specific test framework should not be contained in the
spring repository.

### `testunit`

Runs a test (e.g. Test::Unit, MiniTest::Unit, etc.)

This command can also recursively run a directory of tests. For example,
`spring testunit test/functional` will run `test/functional/**/*_test.rb`.

If your test helper file takes a while to load, consider preloading it
(see "Running code before forking" below).

### `rspec`

Runs an rspec spec, exactly the same as the `rspec` executable.

If your spec helper file takes a while to load, consider preloading it
(see "Running code before forking" below).

### `cucumber`

Runs a cucumber feature.

### `rake`

Runs a rake task. Rake tasks run in the `development` environment by
default. You can change this on the fly by using the `RAILS_ENV`
environment variable. The environment is also configurable with the
`Spring::Commands::Rake.environment_matchers` hash. This has sensible
defaults, but if you need to match a specific task to a specific
environment, you'd do it like this:

``` ruby
Spring::Commands::Rake.environment_matchers["perf_test"] = "test"
Spring::Commands::Rake.environment_matchers[/^perf/]     = "test"
```

### `rails console`, `rails generate`, `rails runner`

These execute the rails command you already know and love. If you run
a different sub command (e.g. `rails server`) then spring will automatically
pass it through to the underlying `rails` executable (without the
speed-up).

## Configuration

Spring will read `~/.spring.rb` and `config/spring.rb` for custom settings, described below.

### Application root

Spring must know how to find your Rails application. If you have a
normal app everything works out of the box. If you are working on a
project with a special setup (an engine for example), you must tell
Spring where your app is located:

```ruby
Spring.application_root = './test/dummy'
```

### Running code before forking

There is no `Spring.before_fork` callback. To run something before the
fork, you can place it in `~/.spring.rb` or `config/spring.rb` or in any of the files
which get run when your application initializers, such as
`config/application.rb`, `config/environments/*.rb` or
`config/initializers/*.rb`.

For example, if loading your test helper is slow, you might like to
preload it to speed up your test runs. To do this you could put a
`require Rails.root.join("test/helper")` in
`config/environments/test.rb`.

### Running code after forking

You might want to run code after Spring forked off the process but
before the actual command is run. You might want to use an
`after_fork` callback if you have to connect to an external service,
do some general cleanup or set up dynamic configuration.

```ruby
Spring.after_fork do
  # run arbitrary code
end
```

If you want to register multiple callbacks you can simply call
`Spring.after_fork` multiple times with different blocks.

### Watching files and directories

Spring will automatically detect file changes to any file loaded when the server
boots. Changes will cause the affected environments to be restarted.

If there are additional files or directories which should trigger an
application restart, you can specify them with `Spring.watch`:

```ruby
Spring.watch "spec/factories"
```

By default Spring polls the filesystem for changes once every 0.2 seconds. This
method requires zero configuration, but if you find that it's using too
much CPU, then you can turn on event-based file system listening:

```ruby
Spring.watch_method = :listen
```

You may need to add the [`listen` gem](https://github.com/guard/listen) to your `Gemfile`.

### tmp directory

Spring needs a tmp directory. This will default to `Rails.root.join('tmp', 'spring')`.
You can set your own configuration directory by setting the `SPRING_TMP_PATH` environment variable.

## Troubleshooting

If you want to get more information about what spring is doing, you can
specify a log file with the `SPRING_LOG` environment variable:

```
spring stop # if spring is already running
export SPRING_LOG=/tmp/spring.log
spring rake -T
```
