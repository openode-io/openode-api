require 'test_helper'

class LibIoCmdTest < ActiveSupport::TestCase
  test "sanitize input cmd with single quote" do
    assert_equal Io::Cmd.sanitize_input_cmd("hell'oworld"), "hell\\\'oworld"
  end

  test "sanitize input, allow spaces" do
    assert_equal Io::Cmd.sanitize_input_cmd("hell oworld"), "hell oworld"
  end

  test "sanitize input cmd with double quote" do
    assert_equal Io::Cmd.sanitize_input_cmd("hell\"\"oworld"), "hell\\\"\\\"oworld"
  end

  test "sanitize input cmd with ;" do
    assert_equal Io::Cmd.sanitize_input_cmd("hell;oworld"), "hell\\;oworld"
  end
end
