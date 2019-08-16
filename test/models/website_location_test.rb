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

    assert wl.domain() == "testsite2.us.openode.io"
  end

  test "domain with usa custom domain" do
    website = Website.find_by site_name: "www.what.is"
    wl = website.website_locations[0]

    assert wl.domain() == "www.what.is"
  end

  test "root domain of google" do
    assert WebsiteLocation.root_domain("www.google.com") == "google.com"
  end

  test "root domain of .nl" do
    assert WebsiteLocation.root_domain("dev.api.abnbouw.nl") == "abnbouw.nl"
  end


end
