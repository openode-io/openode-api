
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

  test "POST /instances/:instance_id/snapshots/create" do
    post "/instances/testsite/snapshots/create",
      as: :json,
      params: { name: "Hello snaps" },
      headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body["result"], "success"

    w = Website.find_by site_name: "testsite"
    assert_equal w.snapshots.length, 2
    assert_equal w.snapshots.last.name, "Hello snaps"
    assert_equal w.snapshots.last.status, "pending"

    assert_equal w.events.count, 1
    assert_equal w.events[0].obj["title"], "snapshot-initiated"
  end

  test "POST /instances/:instance_id/snapshots/create should fail with private cloud" do
    post "/instances/testprivatecloud/snapshots/create",
      as: :json,
      params: { name: "Hello snaps" },
      headers: default_headers_auth

    assert_response :bad_request
  end

end
