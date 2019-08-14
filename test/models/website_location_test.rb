require 'test_helper'

class WebsiteLocationTest < ActiveSupport::TestCase
  test "first website location" do
    website = Website.find_by site_name: "testsite"
    wl = website.website_locations[0]
    
    assert wl.location.str_id == "canada"
  end
end
