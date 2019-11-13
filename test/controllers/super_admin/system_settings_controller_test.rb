require 'test_helper'

class SuperAdmin::SystemSettingsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get super_admin_system_settings_index_url
    assert_response :success
  end

end
