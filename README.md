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
won't be as feature complete as a real shell.

## Usage

Add `spring` to your gemfile and do a `bundle`.

You now have a `spring` command. Do a `rbenv rehash` if necessary. Note
that on my machine I had over 700 gems installed, and activating the gem
to run the `spring` command added over 0.5s to the runtime. Clearing out
my gems solved the problem, but I'd like to figure out a way to speed
this up.

For this walkthrough, I'm using the test app in the Spring repository:

```
cd /path/to/spring/test/apps/rails-3-2
```

We can run a test:

```
$ time spring test test/functional/posts_controller_test.rb
Run options:

# Running tests:

.......

Finished tests in 0.169882s, 41.2051 tests/s, 58.8644 assertions/s.

7 tests, 10 assertions, 0 failures, 0 errors, 0 skips

real	0m1.858s
user	0m0.184s
sys	0m0.067s
```

That booted our app in the background:

```
$ ps ax | grep spring
 8692 pts/6    Sl     0:00 /home/turnip/.rbenv/versions/1.9.3-p194/bin/ruby -r bundler/setup /home/turnip/.rbenv/versions/1.9.3-p194/lib/ruby/gems/1.9.1/gems/spring-0.0.1/lib/spring/server.rb
 8698 pts/6    Sl     0:02 /home/turnip/.rbenv/versions/1.9.3-p194/bin/ruby -r bundler/setup /home/turnip/.rbenv/versions/1.9.3-p194/lib/ruby/gems/1.9.1/gems/spring-0.0.1/lib/spring/server.rb
```

We can see two processes, one is the Spring server, the other is the
application running in the test environment. When we close the terminal,
the processes will be killed automatically.

Running the tests is faster next time:

```
$ time spring test test/functional/posts_controller_test.rb
Run options:

# Running tests:

.......

Finished tests in 0.162963s, 42.9546 tests/s, 61.3637 assertions/s.

7 tests, 10 assertions, 0 failures, 0 errors, 0 skips

real	0m0.492s
user	0m0.179s
sys	0m0.063s
```

If we edit any of the application files, or test files, the change will
be picked up on the next run, without having the background process
having to be restarted. This is because spring makes use of Rails' class
reloading, just like when you make changes in development and see them
when you reload your browser.

If we edit any of the preloaded files, the application needs to restart
automatically. Note that the application process id is 8698 above. Let's
"edit" the `config/application.rb`:

```
$ touch config/application.rb
$ ps ax | grep spring
 8692 pts/6    Sl     0:00 /home/turnip/.rbenv/versions/1.9.3-p194/bin/ruby -r bundler/setup /home/turnip/.rbenv/versions/1.9.3-p194/lib/ruby/gems/1.9.1/gems/spring-0.0.1/lib/spring/server.rb
 8876 pts/6    Sl     0:00 /home/turnip/.rbenv/versions/1.9.3-p194/bin/ruby -r bundler/setup /home/turnip/.rbenv/versions/1.9.3-p194/lib/ruby/gems/1.9.1/gems/spring-0.0.1/lib/spring/server.rb
```

The application process detect the change and exited. The server process
then detected that the application process exited, so it restarted it.
All of this happens automatically in the background. Next time we run a
command we'll be running against a fresh application.

If we run a command that uses a different environment, then it gets
booted up. For example, the `rake` command uses the `development`
environment by default:

```
$ time spring rake routes
    posts GET    /posts(.:format)          posts#index
          POST   /posts(.:format)          posts#create
 new_post GET    /posts/new(.:format)      posts#new
edit_post GET    /posts/:id/edit(.:format) posts#edit
     post GET    /posts/:id(.:format)      posts#show
          PUT    /posts/:id(.:format)      posts#update
          DELETE /posts/:id(.:format)      posts#destroy

real	0m0.763s
user	0m0.185s
sys	0m0.063s
```

We now have 3 processes: the server, and application in test mode and
the application in development mode.

```
$ ps ax | grep spring
 8692 pts/6    Sl     0:00 /home/turnip/.rbenv/versions/1.9.3-p194/bin/ruby -r bundler/setup /home/turnip/.rbenv/versions/1.9.3-p194/lib/ruby/gems/1.9.1/gems/spring-0.0.1/lib/spring/server.rb
 8876 pts/6    Sl     0:15 /home/turnip/.rbenv/versions/1.9.3-p194/bin/ruby -r bundler/setup /home/turnip/.rbenv/versions/1.9.3-p194/lib/ruby/gems/1.9.1/gems/spring-0.0.1/lib/spring/server.rb
 9088 pts/6    Sl     0:01 /home/turnip/.rbenv/versions/1.9.3-p194/bin/ruby -r bundler/setup /home/turnip/.rbenv/versions/1.9.3-p194/lib/ruby/gems/1.9.1/gems/spring-0.0.1/lib/spring/server.rb
```

Running rake is faster the second time:

```
$ time spring rake routes
    posts GET    /posts(.:format)          posts#index
          POST   /posts(.:format)          posts#create
 new_post GET    /posts/new(.:format)      posts#new
edit_post GET    /posts/:id/edit(.:format) posts#edit
     post GET    /posts/:id(.:format)      posts#show
          PUT    /posts/:id(.:format)      posts#update
          DELETE /posts/:id(.:format)      posts#destroy

real	0m0.341s
user	0m0.177s
sys	0m0.070s
```

## Commands

The following commands are shipped by default. There is a
straightforward API for defining your own commands, but currently no way of
hooking in to do so. This is on the TODO list.

### `test`

Runs a test (e.g. Test::Unit, MiniTest::Unit, etc.) Preloads the `test_helper` file.

### `rspec`

Runs an rspec spec, exactly the same as the `rspec` executable. Preloads
the `spec_helper` file.

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
