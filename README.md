# Expedite

![main](https://github.com/johnny-lai/expedite/actions/workflows/ruby.yml/badge.svg)

Expedite is a Ruby preloader manager that allows commands to be executed against 
preloaded Ruby applications. Preloader applications can derive from other preloaders, allowing
derivatives to start faster.

## Usage

To use expedite you need to register variants and commands in an `expedite_helper.rb`
that is placed in the root directory of your application. The sample discussed
in this section is in the [examples/simple](examples/simple) folder.

This is the "parent" variant:
```
# You can pass `keep_alive: true` if you want the variant to restart
# automatically if it is terminated. This option defaults to false.
Expedite::Variants.register('parent') do
  $sleep_parent = 1
end
```

You can register variants that are based on other variants. You can also have wildcard
matchers.
```
Expedite::Variants.register('development/*', parent: 'parent') do |name|
  $sleep_child = name
end
```

You register commands by creating classes in the `Expedite::Command` module. For example,
this defines a `custom` command.

```
Expedite::Commands.register("custom") do
  puts "[#{Expedite.variant}] sleeping for 5"
  puts "$sleep_parent = #{$sleep_parent}"
  puts "$sleep_child = #{$sleep_child}"
  puts "[#{Expedite.variant}] done"
end
```

After registering your variant and commands, you can then use it. In the simple
example, the `main.rb` calls the `custom` command on the `development/abc`
variant.
```
require 'expedite'

Expedite.v("development/abc").call("custom")
```

When you run `main.rb`, the following output is produced. Note that `$sleep_parent`
comes from teh `parent` variant, and `$sleep_child` comes from the `development/abc`
variant.

```
# bundle exec ./main.rb
[development/abc] sleeping for 5
$sleep_parent = 1
$sleep_child = development/abc
[development/abc] done
``

Calling `main.rb` automatically started the expedite server in the background.
In the above example, it does the following:

1. Launch the `base` variant
2. Fork from the `base` variant to create the `development/abc` variant
3. Fork from the `development/abc` variant

To explicitly stop the server and all the variants, you use:

```
$ bundle exec expedite stop
```

You can also start the server in the foreground.

```
$ bundle exec expedite server
```

## Acknowledgements

Expedite server core is modified from [Spring](https://github.com/rails/spring)
