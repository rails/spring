$LOAD_PATH.unshift 'lib'
require 'expedite/version'

Gem::Specification.new do |s|
  s.name        = 'expedite'
  s.version     = Expedite::VERSION
  s.summary     = "Expedite startup of Ruby process"
  s.description = "Manages Ruby processes that can be used to spawn child processes faster."
  s.authors     = ["Bing-Chang Lai"]
  s.email       = 'johnny.lai@me.com'
  s.files       = Dir[
    "README.md",
    "MIT-LICENSE",
    "bin/**/*",
    "lib/**/*"
  ]
  s.executables = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.homepage    = 'https://rubygems.org/gems/expedite'
  s.license     = 'MIT'
end
