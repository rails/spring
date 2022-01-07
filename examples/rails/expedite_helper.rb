require 'expedite'

Expedite.define do
  agent :rails do
    require "rack"

    app_root = Dir.pwd
    rackup_file = "#{app_root}/config.ru"
    Rack::Builder.load_file(rackup_file).first

    Rails.application.eager_load!
  end

  agent 'development/*', parent: 'rails'

  # https://github.com/rails/rails/blob/main/railties/lib/rails/commands/runner/runner_command.rb
  action :runner do |args|
    Rails.application.load_runner

    script = args.shift

    $0 = script
    ARGV.replace(args)

    load script

    123
  end

  action :raise do
    raise ArgumentError, "action raised an error"
  end
end