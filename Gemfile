source 'https://rubygems.org'

# Specify your gem's dependencies in spring.gemspec
gemspec

if ENV["RAILS_VERSION"] == "edge"
  gem "activesupport", github: "rails/rails", branch: "main"
elsif ENV["RAILS_VERSION"]
  gem "activesupport", "~> #{ENV["RAILS_VERSION"] || "6.1"}.0"
end
