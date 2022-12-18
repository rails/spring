require_relative 'custom'

variant = ENV["EXPEDITE_VARIANT"]
puts "expedite_helper -> #{variant}"
case variant
when "parent"
  # Parent stuff
  $sleep_parent = 1
else
  # Child stuff
  $sleep_child = 1
end


require 'expedite/variants'
Expedite::Variants.register('parent')
Expedite::Variants.register('development', parent: 'parent')
