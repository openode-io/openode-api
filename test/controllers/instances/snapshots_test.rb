
require 'test_helper'

class SnapshotsTest < ActionDispatch::IntegrationTest

  test "/instances/:instance_id/storage-areas" do
    w = Website.find_by site_name: "testsite"
    snapshot = w.snapshots.first

    get "/instances/testsite/snapshots/#{snapshot.id}",
      as: :json,
      headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body["id"], snapshot.id
    assert_equal response.parsed_body["name"], snapshot.name
    expected_url = "https://127.0.0.1/snapshots/testsite/#{snapshot.id}.tar.gz"
    assert_equal response.parsed_body["url"], expected_url
  end

end
