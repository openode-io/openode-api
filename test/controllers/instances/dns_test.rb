
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

end
