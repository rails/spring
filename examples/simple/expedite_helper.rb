require 'expedite/commands'
require 'expedite/variants'

Expedite::Variants.register('parent') do
  $sleep_parent = 1
end

Expedite::Variants.register('development/*', parent: 'parent') do |name|
  $sleep_child = name
end

Expedite::Commands.register("custom") do
  puts "[#{Expedite.variant}] sleeping for 5"
  puts "$sleep_parent = #{$sleep_parent}"
  puts "$sleep_child = #{$sleep_child}"
  puts "[#{Expedite.variant}] done"
end
