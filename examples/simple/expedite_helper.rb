require 'expedite/variants'
require_relative 'custom'

Expedite::Variants.register('parent') do
  $sleep_parent = 1
end

Expedite::Variants.register('development/*', parent: 'parent') do |name|
  $sleep_child = name
end
