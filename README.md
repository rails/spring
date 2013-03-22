# Spring

[![Build Status](https://travis-ci.org/jonleighton/spring.png?branch=master)](https://travis-ci.org/jonleighton/spring)

Spring is a Rails application preloader. It's trying to solve the same
problem as [spork](https://github.com/sporkrb/spork),
[zeus](https://github.com/burke/zeus) and
[commands](https://github.com/rails/commands).

I made it because we are having a discussion on the rails core team
about shipping something to solve this problem with rails. So this is my
proposal, as working code.

(At least I hope it's working code, but this is alpha software at the
moment. Please do try it and let me know if you hit problems.)

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

real	0m2.165s
user	0m0.281s
sys	0m0.066s
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

real	0m0.610s
user	0m0.276s
sys	0m0.059s
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

real	0m0.407s
user	0m0.077s
sys	0m0.059s
```

You can add "./bin" to your `PATH` when in your application's directory
[with direnv](https://github.com/zimbatm/direnv), but you should
recognise and understand the security implications of using that.

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

Custom commands can be specified in `config/spring.rb`. See
[`lib/spring/commands.rb`](https://github.com/jonleighton/spring/blob/master/lib/spring/commands.rb)
for examples.

A bunch of different test frameworks are supported at the moment in
order to make it easy for people to try spring. However in the future
the code to use a specific test framework should not be contained in the
spring repository.

### `testunit`

Runs a test (e.g. Test::Unit, MiniTest::Unit, etc.) Preloads the `test_helper` file.

This command can also recursively run a directory of tests. For example,
`spring testunit test/functional` will run `test/functional/**/*_test.rb`.

### `rspec`

Runs an rspec spec, exactly the same as the `rspec` executable. Preloads
the `spec_helper` file.

### `cucumber`

Runs a cucumber feature.

### `rake`

Runs a rake task.

### `rails console`, `rails generate`, `rails runner`

These execute the rails command you already know and love. If you run
a different sub command (e.g. `rails server`) then spring will automatically
pass it through to the underlying `rails` executable (without the
speed-up).

## Configuration

### application_root

Spring must know how to find your rails application. If you have a
normal app everything works out of the box. If you are working on a
project with a special setup (an engine for example), you must tell
Spring where your app is located:

**config/spring.rb**

```ruby
Spring.application_root = './test/dummy'
```

### preload files

Every Spring command has the ability to preload a set of files. The
`test` command for example preloads `test_helper` (it also adds the
`test/` directory to your load path). If the
defaults don't work for your application you can configure the
preloads for every command:

```ruby
# if your test helper is called "helper"
Commands::Command::TestUnit.preloads = %w(helper)

# if you don't want to preload spec_helper.rb
Commands::Command::RSpec.preloads = []

# if you want to preload additional files for the console
Commands::Command::RailsConsole.preloads << 'extenstions/console_helper'
```

### after fork callbacks

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

### tmp directory

Spring needs a tmp directory. This will default to `Rails.root.join('tmp', 'spring')`.
You can set your own configuration directory by setting the `SPRING_TMP_PATH` environment variable.

### Watching files and directories

As mentioned above, Spring will automatically detect file changes to any file loaded when the server
boots. If you would like to watch additional files or directories, use
`Spring.watch`:

```ruby
Spring.watch "#{Rails.root}/spec/factories"
```

### Filesystem polling

By default Spring will check the filesystem for changes once every 0.2 seconds. This
method requires zero configuration, but if you find that it's using too
much CPU, then you can turn on event-based file system listening by
adding the following to to your `Gemfile`:

```ruby
group :development, :test do
  gem 'listen'
  gem 'rb-inotify', :require => false  # linux
  gem 'rb-fsevent', :require => false  # mac os x
  gem 'rb-kqueue',  :require => false  # bsd
end
```

Note that this make the initial application startup slightly slower.
