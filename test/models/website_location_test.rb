require 'test_helper'

class WebsiteLocationTest < ActiveSupport::TestCase
  test "first website location" do
    website = Website.find_by site_name: "testsite"
    wl = website.website_locations[0]

    assert wl.location.str_id == "canada"
  end

  test "domain with canada subdomain" do
    website = Website.find_by site_name: "testsite"
    wl = website.website_locations[0]

    assert wl.domain() == "testsite.openode.io"
  end

  test "domain with usa subdomain" do
    website = Website.find_by site_name: "testsite2"
    wl = website.website_locations[0]

    puts "wl domain #{wl.domain()}"
    assert wl.domain() == "testsite2.us.openode.io"
  end

  test "domain with usa custom domain" do
    website = Website.find_by site_name: "www.what.is"
    wl = website.website_locations[0]

    assert wl.domain() == "www.what.is"
  end
end
