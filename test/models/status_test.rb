require 'test_helper'

class StatusTest < ActiveSupport::TestCase
  test "mongo should be up" do
     assert_equal Status.find_by(name: "Mongodb").status, "up"
  end
end
