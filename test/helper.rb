require "bundler/setup"
require "minitest/autorun"

require_relative "support/test"
Spring::Test.root = File.expand_path('..', __FILE__)
