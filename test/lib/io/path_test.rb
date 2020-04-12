# frozen_string_literal: true

require 'test_helper'

class PathTest < ActiveSupport::TestCase
  test 'is_secure? with basic paths' do
    assert_equal Io::Path.secure?('/home/14/', '/home/14/titi/toto'), true
  end

  test 'is_secure? with dot dot and insecure' do
    assert_equal Io::Path.secure?('/home/14/', '/home/14/../titi/toto'), false
  end

  test 'is_secure? with dot dot and secure' do
    assert_equal Io::Path.secure?('/home/14/', '/home/14/tata/../titi/toto'), true
  end

  test 'is_secure? with dot dot at the beginning' do
    assert_equal Io::Path.secure?('/home/14/', '../elvis/../titi/toto'), false
  end

  test 'is_secure? with nil' do
    assert_equal Io::Path.secure?('/home/14/', nil), false
  end

  test 'is_secure? with root' do
    assert_equal Io::Path.secure?('/home/14/', '/root/test.html'), false
  end

  test 'filter_secure list of files' do
    result = Io::Path.filter_secure('/home/14/', ['/root/test.html', '/home/14/test.txt'])
    assert_equal result.length, 1
    assert_equal result[0], '/home/14/test.txt'
  end

  test 'valid? happy path' do
    assert Io::Path.valid?("/what")
    assert Io::Path.valid?("/what/test.json")
  end

  test 'valid? with newlines' do
    assert_equal Io::Path.valid?("/wh\nat"), false
  end
end
