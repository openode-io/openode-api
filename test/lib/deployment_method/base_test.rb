require 'test_helper'

class DeploymentMethodBaseTest < ActiveSupport::TestCase

  def setup

  end

  test "should have change dir and node" do
    base = DeploymentMethod::Base.new

    result = base.files_listing({ path: "/home/" })
    assert_includes result, "cd #{DeploymentMethod::Base::REMOTE_PATH_API_LIB} &&"
    assert_includes result, "node -e"
  end

  test "should be single line" do
    base = DeploymentMethod::Base.new

    result = base.files_listing({ path: "/home/" })
    assert_equal result.lines.count, 1
  end

end
