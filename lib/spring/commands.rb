require "spring/watcher"

module Spring
  @commands = {}

  class << self
    attr_reader :commands
  end

  def self.register_command(name, klass)
    commands[name] = klass
  end

  def self.command?(name)
    commands.include? name
  end

  def self.command(name)
    commands.fetch name
  end

  require "spring/commands/rails"
  require "spring/commands/rake"
  require "spring/commands/testunit"
  require "spring/commands/rspec"
  require "spring/commands/cucumber"

  # If the config/spring.rb contains requires for commands from other gems,
  # then we need to be under bundler.
  require "bundler/setup"

  # Load custom commands, if any.
  # needs to be at the end to allow modification of existing commands.
  config = File.expand_path("~/.spring.rb")
  require config if File.exist?(config)

  config = File.expand_path("./config/spring.rb")
  require config if File.exist?(config)
end
