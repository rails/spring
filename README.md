# Expedite

![main](https://github.com/johnny-lai/expedite/actions/workflows/ruby.yml/badge.svg)

Expedite is a Ruby preloader manager that allows commands to be executed against 
preloaded Ruby applications. Preloader applications can derive from other preloaders, allowing
derivatives to start faster.

## Usage

Register variants and commands in `expedite_helper.rb`. For example:

```
Expedite::Variants.register('base' do |name|
  puts "Base started"
end
```

You can register variants that are based on other variants, and you can also have wildcard
matchers.
```
Expedite::Variants.register('development/*', parent: 'base') do |name|
  customer = File.basename(name)
  puts "Starting development for #{customer}"
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

Then you can execute a command in the variant using:
```
Expedite.v("development/abc").call("custom")
```

## Acknowledgements

Expedite server core is modified from [Spring](https://github.com/rails/spring)
