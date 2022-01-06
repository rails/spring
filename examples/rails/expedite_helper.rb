require 'expedite/commands'
require 'expedite/variants'

Expedite::Variants.register('preloader') do
  require "rack"

  app_root = Dir.pwd
  rackup_file = "#{app_root}/config.ru"
  Rack::Builder.load_file(rackup_file).first

  Rails.application.eager_load!
end

Expedite::Variants.register('development/*', parent: 'preloader') do |name|
  $sleep_child = name
end

Expedite::Commands.register("custom") do
  puts "$sleep_parent = #{$sleep_parent}"
  puts "$sleep_child = #{$sleep_child}"
  puts $app
end

# https://github.com/rails/rails/blob/main/railties/lib/rails/commands/runner/runner_command.rb
Expedite::Commands.register("runner") do |args|
  Rails.application.load_runner

  script = args.shift

  $0 = script
  ARGV.replace(args)

  load script
  
  123
end

Expedite::Commands.register("raise") do
  raise ArgumentError, "blah"
end

#module X
#  def runner(*args)
#  end
#
#  def stuff()
#  end
#end
#Expedite::Commands.export(X)
