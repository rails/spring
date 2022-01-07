Run the `main.rb` script.

```
$ bundle exec ruby main.rb
[development/abc] sleeping for 5
$sleep_parent = 1
$sleep_child = development/abc
[development/abc] done
```

Notice how `$sleep_parent` is set to `1`. This value was set in the parent process, and
then inherited in the child.

You can see the preloader agents from `expedite status`
```
$ bundle exec expedite status
Expedite is running (pid=48529)

48529 expedite server | simple   
48531 expedite agent | simple | development/abc    
48530 expedite agent | simple | parent    
```