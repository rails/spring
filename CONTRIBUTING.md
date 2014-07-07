# Don't use the issue tracker to ask questions

Please use Stack Overflow or similar. If you subsequently feel that the
documentation is inadequate then plase submit a pull request to fix it.

# Contributing guide

## Getting set up

Check out the code and run `bundle install` as usual.

## Running tests

Running `rake` will run all tests. There are both unit tests and
acceptance tests. You can run them individually with `rake test:unit` or
`rake test:acceptance`.

If one doesn't already exist, the acceptance tests will generate a dummy
Rails app in `test/apps/`. On each test run, the dummy app is copied to
`test/apps/tmp/` so that any changes won't affect the pre-generated app
(this saves us having to regenerate the app on each run).

If tests are failing and you don't know why, it might be that the
pre-generated app has become inconsistent in some way. In that case the
best solution is to purge it with `rm -rf test/apps/*` and then run the
acceptance tests again, which will generate a new app.

## Testing different Rails versions

You can set the `RAILS_VERSION` environment variable:

```
$ RAILS_VERSION="~> 3.2.0" rake test:acceptance
```

The apps in `test/apps` will be named based on the rails version and the
spring version.

## Testing with your app

You cannot link to a git repo from your Gemfile. Spring doesn't support
this due to the way that it gets loaded (bypassing bundler for
performance reasons).

Therefore, to test changes with your app, run `rake install` to properly
install the gem on your system.

## Submitting a pull request

If your change is a bugfix or feature, please make sure you add to
`CHANGELOG.md` under the "Next Release" heading (add the heading if
needed).
