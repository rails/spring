require_relative "../helper"
require 'spring/json'

class JsonTest < ActiveSupport::TestCase
  test 'can decode unicode characters' do
    assert_equal({"unicode_example"=>"©"}, Spring::JSON.load('{"unicode_example": "\u00A9"}'))
  end

  test 'can encode' do
    assert_equal('{}', Spring::JSON.dump({}))
  end 
end
