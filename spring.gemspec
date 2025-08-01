require './lib/spring/version'

Gem::Specification.new do |gem|
  gem.name          = "spring"
  gem.version       = Spring::VERSION
  gem.authors       = ["Jon Leighton"]
  gem.email         = ["j@jonathanleighton.com"]
  gem.summary       = "Rails application preloader"
  gem.description   = "Preloads your application so things like console, rake and tests run faster"
  gem.homepage      = "https://github.com/rails/spring"
  gem.license       = "MIT"

  gem.files         = Dir["LICENSE.txt", "README.md", "lib/**/*", "bin/*"]
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }

  gem.required_ruby_version = ">= 2.7.0"

  gem.metadata = {
    "rubygems_mfa_required" => "true",
    "changelog_uri" => "https://github.com/rails/spring/blob/main/CHANGELOG.md"
  }
end
