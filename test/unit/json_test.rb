require_relative "../helper"
require 'spring/json'

class JsonTest < ActiveSupport::TestCase
  test 'can decode unicode characters' do
    assert_equal({"unicode_example"=>"©"}, Spring::JSON.load('{"unicode_example": "\u00A9"}'))
  end

  test 'can decode binary strings with valid UTF8 characters' do
    string = "{\"PS1\":\"\xEF\x90\x98 main \xEE\x9E\x91 v3.4.2\"}".b
    assert_equal({"PS1"=>" main  v3.4.2"}, Spring::JSON.load(string))
  end

  test 'can encode' do
    assert_equal('{}', Spring::JSON.dump({}))
  end
end
