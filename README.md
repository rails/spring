# Expedite

![main](https://github.com/johnny-lai/expedite/actions/workflows/ruby.yml/badge.svg)

Expedite is a Ruby preloader manager that allows commands to be executed against 
preloaded Ruby applications. Preloader applications can derive from other preloaders, allowing
derivatives to start faster.

## Usage

To use expedite you need to define agents and actions in an `expedite_helper.rb`
that is placed in the root directory of your application. The sample discussed
in this section is in the [examples/simple](examples/simple) folder.

This is the "parent" agent:
```
Expedite.define do
  agent :parent do
    $parent_var = 1
  end
end
```

You can define agents that are based on other agents. You can also have wildcard
matchers.

```
Expedite.define do
  agent "development/*", parent: :parent do |name|
    $development_var = name
  end
end
```

The following defines an `info` action.

```
Expedite.define do
  action :info do
    puts "     Process.pid = #{Process.pid}"
    puts "    Process.ppid = #{Process.ppid}"
    puts "     $parent_var = #{$parent_var}"
    puts "$development_var = #{$development_var}"
  end
end
```

After defining your agents and actions, you can then use it. In the simple
example, the `main.rb` calls the `info` command on the `development/abc`
agent.

The `invoke` method will execute the action, and return the result. There
is also an `exec` method that will replace the current executable with
the action; in that case, the return result is the exit code.
```
require 'expedite'

Expedite.agent("development/abc").invoke("info")
```

When you run `main.rb`, the following output is produced. Note that `$sleep_parent`
comes from teh `parent` agent, and `$sleep_child` comes from the `development/abc`
agent.

```
# bundle exec ./main.rb
     Process.pid = 3855
    Process.ppid = 3854
     $parent_var = 1
$development_var = development/abc
```

Calling `main.rb` automatically started the expedite server in the background.
In the above example, it does the following:

1. Launch the `parent` agent.
2. Fork from the `parent` agent to create the `development/abc` agent.
3. Fork from the `development/abc` agent to run the `info` command, and then quit.

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
