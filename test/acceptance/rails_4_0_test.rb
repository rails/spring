require_relative 'spring_acceptance_tests'

class Rails_4_0_Test < ActiveSupport::TestCase
  include SpringAcceptanceTests

  def app_root
    Pathname.new("#{TEST_ROOT}/apps/rails-4-0")
  end

  def controller_test_path
    "#{app_root}/test/controllers/posts_controller_test.rb"
  end
end

