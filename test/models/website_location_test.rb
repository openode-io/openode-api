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

    assert wl.main_domain() == "testsite.openode.io"
  end

  test "domain with usa subdomain" do
    website = Website.find_by site_name: "testsite2"
    wl = website.website_locations[0]

    assert wl.main_domain() == "testsite2.us.openode.io"
  end

  test "domain with usa custom domain" do
    website = Website.find_by site_name: "www.what.is"
    wl = website.website_locations[0]

    assert wl.main_domain() == "www.what.is"
  end

  # root domain of website location
  test "root domain with usa custom domain" do
    website = Website.find_by site_name: "www.what.is"
    wl = website.website_locations[0]

    assert wl.root_domain() == "what.is"
  end

  # compute domains of website location
  test "compute domains with usa custom domain" do
    website = Website.find_by site_name: "www.what.is"
    website.domains = ["www.what.is", "www2.www.what.is"]
    website.save!
    wl = website.website_locations[0]

    assert wl.compute_domains == ["www.what.is", "www2.www.what.is"]
  end

  test "compute domains with usa subdomain" do
    website = Website.find_by site_name: "testsite2"
    wl = website.website_locations[0]

    assert wl.compute_domains == ["testsite2.us.openode.io"]
  end

  # generic root domain
  test "root domain of google" do
    assert WebsiteLocation.root_domain("www.google.com") == "google.com"
  end

  test "root domain of .nl" do
    assert WebsiteLocation.root_domain("dev.api.abnbouw.nl") == "abnbouw.nl"
  end


end
