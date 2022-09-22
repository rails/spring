source 'https://rubygems.org'

# Specify your gem's dependencies in spring.gemspec
gemspec

if ENV["RAILS_VERSION"] == "edge"
  gem "activesupport", github: "rails/rails", branch: "main"
elsif ENV['RAILS_VERSION'] == "7.0"
  gem "activesupport", ">= 7.0.0.alpha"
elsif ENV["RAILS_VERSION"]
  gem "activesupport", "~> #{ENV["RAILS_VERSION"]}.0"
end
