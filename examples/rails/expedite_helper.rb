require 'expedite'
require 'expedite/helper/rails'

Expedite.define do
  agent 'development/*', parent: :rails_environment

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
