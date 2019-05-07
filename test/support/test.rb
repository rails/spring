require "active_support"
require "active_support/test_case"

ActiveSupport.test_order = :random

module Spring
  module Test
    class << self
      attr_accessor :root
    end

    require_relative "application"
    require_relative "application_generator"
    require_relative "rails_version"
    require_relative "watcher_test"
    require_relative "acceptance_test"
  end
end
