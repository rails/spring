
Expedite.define do
  # Agent that rails environment loaded
  agent :rails_environment do
    app_root = Dir.pwd
    require "#{app_root}/config/environment.rb"
  end
end
