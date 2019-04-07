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

  # We don't directly use Active Support (Spring needs to be able to run
  # without gem dependencies), but this will ensure that this version of
  # Spring can't be installed alongside an incompatible Rails version.
  gem.add_dependency 'activesupport', '>= 4.2'

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'bump'
  gem.add_development_dependency 'sqlite3'
end
