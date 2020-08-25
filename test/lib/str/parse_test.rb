require 'test_helper'

class StrParseTest < ActiveSupport::TestCase
  def setup; end

  test 'integer - if str is instance' do
    assert_equal Str::Parse.integer?("123456"), true
  end

  test 'integer - starts with letters' do
    assert_equal Str::Parse.integer?("a123456"), false
  end

  test 'integer - ends with letters' do
    assert_equal Str::Parse.integer?("123456aa"), false
  end

  test 'integer - letters only' do
    assert_equal Str::Parse.integer?("aa"), false
  end

  test 'integer - letters in the middle' do
    assert_equal Str::Parse.integer?("1234aa1234"), false
  end
end
