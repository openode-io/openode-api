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

  test "compute_a_record_dns with two domains" do
    server = LocationServer.find_by ip: "127.0.0.1"

    result =
      WebsiteLocation.compute_a_record_dns(server, ["google.com", "www.google.com"])

    assert_equal result.length, 2
    assert_equal result[0]["domainName"], "google.com"
    assert_equal result[0]["type"], "A"
    assert_equal result[0]["value"], "127.0.0.1"

    assert_equal result[1]["domainName"], "www.google.com"
    assert_equal result[1]["type"], "A"
    assert_equal result[1]["value"], "127.0.0.1"
  end

  # compute_dns
  test "compute dns with one domain and no dns entry" do
    website = Website.find_by site_name: "www.what.is"
    website.domains = ["www.what.is"]
    website.dns = []
    website.save!
    wl = website.website_locations[0]

    assert wl.compute_dns == []
  end

  test "compute dns with one domain and one dns entry" do
    website = Website.find_by site_name: "www.what.is"
    website.domains = ["www.what.is"]

    entry1 = {
      domainName: "www.what.is",
      type: "A",
      value: "127.0.0.10"
    }

    website.dns = [entry1]
    website.save!
    website.reload
    wl = website.website_locations[0]

    result = wl.compute_dns()

    assert_equal result.length, 1
    assert_equal result[0]["domainName"], "www.what.is"
    assert_equal result[0]["type"], "A"
    assert_equal result[0]["value"], "127.0.0.10"
    assert_equal result[0]["id"], WebsiteLocation.dns_entry_to_id(entry1)
  end

  test "compute dns with one domain, one dns entry, and auto a" do
    website = Website.find_by site_name: "www.what.is"
    website.domains = ["www.what.is"]

    entry1 = {
      domainName: "www.what.is",
      type: "A",
      value: "127.0.0.10"
    }

    website.dns = [entry1]
    website.save!
    website.reload
    wl = website.website_locations[0]

    result = wl.compute_dns({ with_auto_a: true })

    assert_equal result.length, 2
    assert_equal result[0]["domainName"], "www.what.is"
    assert_equal result[0]["type"], "A"
    assert_equal result[0]["value"], "127.0.0.10"
    assert_equal result[0]["id"], WebsiteLocation.dns_entry_to_id(entry1)

    assert_equal result[1]["domainName"], "www.what.is"
    assert_equal result[1]["type"], "A"
    assert_equal result[1]["value"], wl.location_server.ip
    assert_equal result[1]["id"], WebsiteLocation.dns_entry_to_id({
      domainName: "www.what.is",
      type: "A",
      value: wl.location_server.ip
    })
  end

  # generic root domain
  test "root domain of google" do
    assert WebsiteLocation.root_domain("www.google.com") == "google.com"
  end

  test "root domain of .nl" do
    assert WebsiteLocation.root_domain("dev.api.abnbouw.nl") == "abnbouw.nl"
  end


end
