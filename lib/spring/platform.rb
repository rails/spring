module Spring
  def self.fork?
    Process.respond_to?(:fork)
  end

  def self.jruby?
    RUBY_ENGINE == "jruby"
  end

  def self.ruby_bin
    if RUBY_ENGINE == "jruby"
      "jruby"
    else
      "ruby"
    end
  end

  if jruby?
    IGNORE_SIGNALS = %w(INT)
    FORWARDED_SIGNALS = %w(INT USR2 INFO WINCH) & Signal.list.keys
  else
    IGNORE_SIGNALS = %w(INT QUIT)
    FORWARDED_SIGNALS = %w(INT QUIT USR1 USR2 INFO WINCH) & Signal.list.keys
  end
end
