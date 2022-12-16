Expedite.define do
  # Agent that rails environment loaded
  agent :rails_environment do
    app_root = Dir.pwd
    require "#{app_root}/config/environment.rb"
  end

  # Actions that runs rails commands
  action :rails_commands do |args|
    ARGV.replace(args)
    require "rails/commands"
    true
  end
end
