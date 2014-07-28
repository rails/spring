$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require "bundler/setup"
require "minitest/autorun"

require "spring/test"
Spring::Test.root = File.expand_path('..', __FILE__)
