Contributing to Spring
=====================

[![Build Status](https://travis-ci.org/rails/spring.svg?branch=master)](https://travis-ci.org/rails/spring)
[![Gem Version](https://badge.fury.io/rb/spring.svg)](http://badge.fury.io/rb/spring)

Spring is work of [many contributors](https://github.com/rails/spring/graphs/contributors). You're encouraged to submit [pull requests](https://github.com/rails/spring/pulls), [propose features and discuss issues](https://github.com/rails/spring/issues).

# Don't use the issue tracker to ask questions

Please use Stack Overflow or similar. If you subsequently feel that the
documentation is inadequate then plase submit a pull request to fix it.

#### Fork the Project

Fork the [project on Github](https://github.com/rails/spring) and check out your copy.

```
git clone https://github.com/contributor/spring.git
cd spring
git remote add upstream https://github.com/rails/spring.git
```

#### Create a Topic Branch

Make sure your fork is up-to-date and create a topic branch for your feature or bug fix.

```
git checkout master
git pull upstream master
git checkout -b my-feature-branch
```

#### Bundle Install and Test

Ensure that you can build the project and run tests.

```
bundle install
bundle exec rake
```

#### Write Tests

Try to write a test that reproduces the problem you're trying to fix or describes a feature that you want to build. Add to [test](test).

We definitely appreciate pull requests that highlight or reproduce a problem, even without a fix.

There are both unit tests and acceptance tests. You can run them individually with `rake test:unit` or `rake test:acceptance`. You can also run single tests by matching test names `ruby test/unit/process_title_updater_test.rb -n '/hours/'`

If one doesn't already exist, the acceptance tests will generate a dummy
Rails app in `test/apps/`. On each test run, the dummy app is copied to
`test/apps/tmp/` so that any changes won't affect the pre-generated app
(this saves us having to regenerate the app on each run).

If tests are failing and you don't know why, it might be that the
pre-generated app has become inconsistent in some way. In that case the
best solution is to purge it with `rm -rf test/apps/*` and then run the
acceptance tests again, which will generate a new app.

To test against version of Rails, you can set the `RAILS_VERSION` environment variable:

```
$ RAILS_VERSION="~> 3.2.0" rake test:acceptance
```

The apps in `test/apps` will be named based on the rails version and the
spring version.

#### Write Code

Implement your feature or bug fix.

Make sure that `bundle exec rake test` completes without errors.

#### Write Documentation

Document any external behavior in the [README](README.md).

#### Commit Changes

Make sure git knows your name and email address:

```
git config --global user.name "Your Name"
git config --global user.email "contributor@example.com"
```

Writing good commit logs is important. A commit log should describe what changed and why.

```
git add ...
git commit
```

#### Push

```
git push origin my-feature-branch
```

#### Make a Pull Request

Go to https://github.com/contributor/spring and select your feature branch. Click the 'Pull Request' button and fill out the form. Pull requests are usually reviewed within a few days.

#### Rebase

If you've been working on a change for a while, rebase with upstream/master.

```
git fetch upstream
git rebase upstream/master
git push origin my-feature-branch -f
```

#### Check on Your Pull Request

Go back to your pull request after a few minutes and see whether it passed muster with Travis-CI. Everything should look green, otherwise fix issues and amend your commit as described above.

#### Be Patient

It's likely that your change will not be merged and that the nitpicky maintainers will ask you to do more, or fix seemingly benign problems. Hang on there!

#### Thank You

Please do know that we really appreciate and value your time and work. We love you, really.
