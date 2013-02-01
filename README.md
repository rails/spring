# Spring

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

At the moment only MRI 1.9.3 / Rails 3.2 is supported.

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
$ time spring test test/functional/posts_controller_test.rb
Rack::File headers parameter replaces cache_control after Rack 1.5.
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
$ ps ax | grep spring
26150 pts/3    Sl     0:00 spring server | rails-3-2 | started 2013-02-01 20:16:40 +0000
26155 pts/3    Sl     0:02 spring app    | rails-3-2 | started 2013-02-01 20:16:40 +0000 | test mode
```

We can see two processes, one is the Spring server, the other is the
application running in the test environment. When we close the terminal,
the processes will be killed automatically.

Running the test is faster next time:

```
$ time spring test test/functional/posts_controller_test.rb
Run options:

# Running tests:

.......

Finished tests in 0.176896s, 39.5714 tests/s, 56.5305 assertions/s.

7 tests, 10 assertions, 0 failures, 0 errors, 0 skips

real	0m0.610s
user	0m0.276s
sys	0m0.059s
```

Running `spring test`, `spring rake`, `spring console`, etc gets a bit
tedious. It also suffers from a performance issue in Rubygems ([which I
am actively working on](https://github.com/rubygems/rubygems/pull/435))
which means the `spring` command takes a while to start up. The more
gems you have, the longer it takes.

Spring binstubs solve both of these problems. If you will be running the
`test` command regularly, run:

```
$ spring binstub test
```

This generates a `bin/spring` and a `bin/test`, which allows you to run
`spring` and `spring test` in a way that doesn't trigger the Rubygems
performance bug:

```
$ time bin/test test/functional/posts_controller_test.rb
Run options:

# Running tests:

.......

Finished tests in 0.166585s, 42.0207 tests/s, 60.0296 assertions/s.

7 tests, 10 assertions, 0 failures, 0 errors, 0 skips

real	0m0.407s
user	0m0.077s
sys	0m0.059s
```

If we edit any of the application files, or test files, the change will
be picked up on the next run, without having the background process
having to be restarted. This works even if you e.g. referenced your
`Post` model in an initializer and then edited it.

If we edit any of the preloaded files, the application needs to restart
automatically. Note that the application process id is 8698 above. Let's
"edit" the `config/application.rb`:

```
$ touch config/application.rb
$ ps ax | grep spring
26150 pts/3    Sl     0:00 spring server | rails-3-2 | started 2013-02-01 20:16:40 +0000
26556 pts/3    Sl     0:00 spring app    | rails-3-2 | started 2013-02-01 20:20:07 +0000 | test mode
```

The application process detected the change and exited. The server process
then detected that the application process exited, so it started a new application.
All of this happens automatically in the background. Next time we run a
command we'll be running against a fresh application. We can see that
the start time and PID of the app process has now changed.

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
$ ps ax | grep spring
26150 pts/3    Sl     0:00 spring server | rails-3-2 | started 2013-02-01 20:16:40 +0000
26556 pts/3    Sl     0:08 spring app    | rails-3-2 | started 2013-02-01 20:20:07 +0000 | test mode
26707 pts/3    Sl     0:00 spring app    | rails-3-2 | started 2013-02-01 20:22:41 +0000 | development mode
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

### `test`

Runs a test (e.g. Test::Unit, MiniTest::Unit, etc.) Preloads the `test_helper` file.

This command can also recursively run a directory of tests. For example,
`spring test test/functional` will run `test/functional/**/*_test.rb`.

### `rspec`

Runs an rspec spec, exactly the same as the `rspec` executable. Preloads
the `spec_helper` file.

### `cucumber`

Runs a cucumber feature.

### `rake`

Runs a rake task.

### `console`

Boots into the Rails console. Currently this is usable but not perfect,
for example you can't scroll back through command history. (That will be
fixed.)

### `generate`

Runs a Rails generator.

### `runner`

The Rails runner.

## Configuration

### tmp directory

Spring needs a tmp directory. This will default to `Rails.root + 'tmp' + 'spring'`.
You can set your own configuration directory by setting the `SPRING_TMP_PATH` environment variable.
