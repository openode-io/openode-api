require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test "encrypt_passwd correctly" do
    salt = "$2a$10$ThisIsTheSalt22CharsX."
    expected_encryption = "$2a$10$ThisIsTheSalt22CharsX.ZJyiIxDe4rFcyc7N/fw8gkI4Dvu0gKi"
    assert User.encrypt_passwd("hello", salt) == expected_encryption
  end

  test "encrypt_passwd passwd_valid?" do
    expected_encryption = "$2a$10$ThisIsTheSalt22CharsX.ZJyiIxDe4rFcyc7N/fw8gkI4Dvu0gKi"
    assert User.passwd_valid?(expected_encryption, "hello")
  end
end
