# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'spring/version'

Gem::Specification.new do |gem|
  gem.name          = "spring"
  gem.version       = Spring::VERSION
  gem.authors       = ["Jon Leighton"]
  gem.email         = ["j@jonathanleighton.com"]
  gem.description   = %q{Rails application preloader}
  gem.summary       = %q{Rails application preloader}
  gem.homepage      = "http://github.com/rails/spring"
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency 'activesupport', '~> 4.2.0'
  gem.add_development_dependency 'rake'
end
