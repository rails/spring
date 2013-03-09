require_relative 'spring_acceptance_tests'

class Rails_3_0_Test < ActiveSupport::TestCase
  include SpringAcceptanceTests

  def app_root
    Pathname.new("#{TEST_ROOT}/apps/rails-3-0")
  end
end


