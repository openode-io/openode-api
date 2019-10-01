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

  # TODO verify_can_deploy

end
