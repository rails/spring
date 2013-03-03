require 'spring_acceptance_tests'

class Rails_3_1_Test < ActiveSupport::TestCase
  include SpringAcceptanceTests

  def app_root
    Pathname.new("#{TEST_ROOT}/apps/rails-3-1")
  end
end

