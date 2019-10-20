
require 'test_helper'

class DnsTest < ActionDispatch::IntegrationTest

  test "/instances/:instance_id/list-dns with subdomain should fail" do
    get "/instances/testsite/list-dns", as: :json, headers: default_headers_auth

    assert_response :bad_request
  end

  test "/instances/:instance_id/list-dns with custom domain" do
    w = Website.find_by site_name: "www.what.is"
    w.domains = ["www.what.is"]
    w.save!

    get "/instances/www.what.is/list-dns", as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]["domainName"], "www.what.is"
    assert_equal response.parsed_body[0]["type"], "A"
    assert_equal response.parsed_body[0]["id"].present?, true
  end

  test "/instances/:instance_id/add-dns with subdomain should fail" do
    w = Website.find_by site_name: "testsite"
    w.save!

    post "/instances/testsite/add-dns", 
      as: :json,
      params: { domainName: "www2.www.what.is", type: "A", value: "127.0.0.4" },
      headers: default_headers_auth

    assert_response :bad_request
  end

  test "/instances/:instance_id/add-dns with subdomain and without server should fail" do
    w = Website.find_by site_name: "www.what.is"
    w.domains = ["www.what.is", "www2.www.what.is"]
    w.dns = []
    w.save!
    website_location = w.website_locations.first
    website_location.location_server_id = nil
    website_location.save!

    post "/instances/www.what.is/add-dns", 
      as: :json,
      params: { domainName: "www2.www.what.is", type: "A", value: "127.0.0.4" },
      headers: default_headers_auth

    assert_response :bad_request
  end

  test "/instances/:instance_id/add-dns with custom domain" do
    w = Website.find_by site_name: "www.what.is"
    w.domains = ["www.what.is", "www2.www.what.is"]
    w.dns = []
    w.save!

    post "/instances/www.what.is/add-dns", 
      as: :json,
      params: { domainName: "www2.www.what.is", type: "A", value: "127.0.0.4" },
      headers: default_headers_auth

    w.reload

    assert_response :success
    assert_equal w.dns[0]["domainName"], "www2.www.what.is"
    assert_equal w.dns[0]["type"], "A"
    assert_equal w.dns[0]["value"], "127.0.0.4"
  end

  test "/instances/:instance_id/del-dns with custom domain" do
    w = Website.find_by site_name: "www.what.is"
    w.domains = ["www.what.is", "www2.www.what.is"]
    w.dns = []
    w.save!

    post "/instances/www.what.is/add-dns", 
      as: :json,
      params: { domainName: "www2.www.what.is", type: "A", value: "127.0.0.4" },
      headers: default_headers_auth

    w.events.destroy_all
    w.reload
    entry_added = w.website_locations.first.compute_dns.first

    delete "/instances/www.what.is/del-dns?id=#{entry_added["id"]}", 
      as: :json,
      headers: default_headers_auth

    w.reload
    puts "events #{w.events.inspect}"

    assert_response :success
    assert_equal w.website_locations.first.compute_dns.length, 0

    assert_equal w.events.length, 2
    assert_equal w.events[0].obj["title"], "DNS update"
    assert_equal w.events[0].obj["updates"]["deleted"].length, 1
    assert_equal w.events[0].obj["updates"]["deleted"][0]["domainName"], "www2.www.what.is"
    assert_equal w.events[0].obj["updates"]["deleted"][0]["type"], "A"
    assert_equal w.events[0].obj["updates"]["deleted"][0]["value"], "127.0.0.4"
    assert_equal w.events[1].obj["title"], "Remove DNS entry"
  end

end
