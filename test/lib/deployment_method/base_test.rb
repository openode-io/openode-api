require 'test_helper'

class DeploymentMethodBaseTest < ActiveSupport::TestCase

  def setup

  end

  test "mark accessed" do
  	website = Website.find_by site_name: "testsite"
    base_dep_method = DeploymentMethod::Base.new

    website.last_access_at = nil
    website.save!

    base_dep_method.mark_accessed({ website: website })
    website.reload

    assert_equal Time.now - website.last_access_at <= 5, true
  end

  test "initialization" do
    website = Website.find_by site_name: "testsite"
    base_dep_method = DeploymentMethod::Base.new

    website.last_access_at = nil
    website.save!
    website.change_status!(Website::STATUS_OFFLINE)
    website_location = website.website_locations.first

    base_dep_method.initialization({ website: website, website_location: website_location })
    website.reload

    assert_equal Time.now - website.last_access_at <= 5, true
    assert_equal website.status, Website::STATUS_STARTING
  end

  test "verify_can_deploy without failure" do
    website = default_website
    website_location = website.website_locations.first
    base_dep_method = DeploymentMethod::Base.new

    base_dep_method.verify_can_deploy({ website: website, website_location: website_location })
  end

  test "verify_can_deploy with failure" do
    website = default_website
    website_location = website.website_locations.first
    base_dep_method = DeploymentMethod::Base.new

    website.user.activated = false
    website.user.save

    begin
      base_dep_method.verify_can_deploy({ website: website, website_location: website_location })
      assert_equal true, false
    rescue => ex
      assert_equal ex.class, ApplicationRecord::ValidationError
    end
  end

  test "instance_up_cmd" do
    base_dep_method = DeploymentMethod::Base.new

    cmd = base_dep_method.instance_up_cmd({ website_location: default_website_location })
    assert_includes cmd, "curl "
    assert_includes cmd, "http://localhost:#{default_website_location.port}/"
  end

end
