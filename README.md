# Expedite

![main](https://github.com/johnny-lai/expedite/actions/workflows/ruby.yml/badge.svg)

Expedite is a Ruby preloader manager that allows commands to be executed against 
preloaded Ruby applications. Preloader applications can derive from other preloaders, allowing
derivatives to start faster.

## Usage

To use expedite you need to register agents and commands in an `expedite_helper.rb`
that is placed in the root directory of your application. The sample discussed
in this section is in the [examples/simple](examples/simple) folder.

This is the "parent" agent:
```
# You can pass `keep_alive: true` if you want the agent to restart
# automatically if it is terminated. This option defaults to false.
Expedite::Agents.register('parent') do
  $sleep_parent = 1
end
```

You can register agents that are based on other agents. You can also have wildcard
matchers.
```
Expedite::Agents.register('development/*', parent: 'parent') do |name|
  $sleep_child = name
end
```

You register commands by creating classes in the `Expedite::Action` module. For example,
this defines a `custom` command.

```
Expedite::Actions.register("custom") do
  puts "[#{Expedite.agent}] sleeping for 5"
  puts "$sleep_parent = #{$sleep_parent}"
  puts "$sleep_child = #{$sleep_child}"
  puts "[#{Expedite.agent}] done"
end
```

After registering your agent and commands, you can then use it. In the simple
example, the `main.rb` calls the `custom` command on the `development/abc`
agent.

```
require 'expedite'

Expedite.agent("development/abc").invoke("custom")
```

When you run `main.rb`, the following output is produced. Note that `$sleep_parent`
comes from teh `parent` agent, and `$sleep_child` comes from the `development/abc`
agent.

```
# bundle exec ./main.rb
[development/abc] sleeping for 5
$sleep_parent = 1
$sleep_child = development/abc
[development/abc] done
```

Calling `main.rb` automatically started the expedite server in the background.
In the above example, it does the following:

1. Launch the `base` agent
2. Fork from the `base` agent to create the `development/abc` agent
3. Fork from the `development/abc` agent

To explicitly stop the server and all the agents, you use:

```
$ bundle exec expedite stop
```

You can also start the server in the foreground.

```
$ bundle exec expedite server
```

## Acknowledgements

Expedite's server core is modified from [Spring](https://github.com/rails/spring)
