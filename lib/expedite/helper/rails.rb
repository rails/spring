
Expedite.define do
  agent :rails_environment do
    app_root = Dir.pwd

    require "#{app_root}/config/boot.rb"

    require "rack"
    rackup_file = "#{app_root}/config.ru"
    Rack::Builder.load_file(rackup_file)

    Rails.application.eager_load!
  end
end
