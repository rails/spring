$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require "bundler/setup"
require "active_support/test_case"
require "minitest/autorun"

TEST_ROOT = File.expand_path('..', __FILE__)
