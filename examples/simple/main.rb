#!/usr/bin/env ruby
require 'expedite'

Expedite.pool("development").call("custom")

#Expedite.with("development").exec do
#  $x = 1
#end
