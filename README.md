# Expedite

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
module Expedite
  module Command
    class Custom
      def call
        puts "custom command"
      end

      def exec_name
        "custom"
      end

      def setup(client)
      end
    end
  end
end
```

Then you can execute a command in the variant using:
```
Expedite.v("development/abc").call("custom")
```
