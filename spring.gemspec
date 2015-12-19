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

  gem.add_dependency 'bundler', '>= 1.0'
  gem.add_development_dependency 'activesupport', '~> 4.2.0'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'bump'
end
