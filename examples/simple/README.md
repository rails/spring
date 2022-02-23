Run the `main.rb` script.

```
$ bundle exec ./main.rb
     Process.pid = 3855
    Process.ppid = 3854
     $parent_var = 1
$development_var = development/abc
```

Notice how `$parent_var` is set to `1`. This value was set in the parent process, and
then inherited in the child.

You can see the preloader agents from `expedite status`
```
$ bundle exec expedite status
Expedite is running (pid=48529)

48529 expedite server | simple   
48531 expedite agent | simple | development/abc    
48530 expedite agent | simple | parent    
```
