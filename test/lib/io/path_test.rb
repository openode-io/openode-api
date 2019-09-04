require 'test_helper'

class PathTest < ActiveSupport::TestCase
  test "is_secure? with basic paths" do
    assert_equal Io::Path.is_secure?("/home/14/", "/home/14/titi/toto"), true
  end

  test "is_secure? with dot dot and insecure" do
    assert_equal Io::Path.is_secure?("/home/14/", "/home/14/../titi/toto"), false
  end

  test "is_secure? with dot dot and secure" do
    assert_equal Io::Path.is_secure?("/home/14/", "/home/14/tata/../titi/toto"), true
  end

  test "is_secure? with dot dot at the beginning" do
    assert_equal Io::Path.is_secure?("/home/14/", "../elvis/../titi/toto"), false
  end

  test "is_secure? with nil" do
    assert_equal Io::Path.is_secure?("/home/14/", nil), false
  end

  test "is_secure? with root" do
    assert_equal Io::Path.is_secure?("/home/14/", "/root/test.html"), false
  end
end
