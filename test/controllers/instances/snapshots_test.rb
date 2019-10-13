
require 'test_helper'

class SnapshotsTest < ActionDispatch::IntegrationTest

  test "/instances/:instance_id/snapshots/id" do
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

  test "/instances/:instance_id/snapshots/ listing" do
    website = default_website
    snapshot = website.snapshots.first

    get "/instances/testsite/snapshots",
      as: :json,
      headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]["id"], snapshot.id
    assert_equal response.parsed_body[0]["name"], snapshot.name
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

  test "DELETE /instances/:instance_id/snapshots/:id should change the status properly" do
    website = default_website

    post "/instances/testsite/snapshots/create",
      as: :json,
      params: { name: "Hello snaps" },
      headers: default_headers_auth

    snapshot = website.snapshots.find_by name: "Hello snaps"

    delete "/instances/testsite/snapshots/#{snapshot.id}",
      as: :json,
      headers: default_headers_auth

    snapshot.reload

    assert_response :success
    assert_equal snapshot.status, "to_delete"
  end

  test "DELETE /instances/:instance_id/snapshots/:id should fail if already deleted" do
    website = default_website

    post "/instances/testsite/snapshots/create",
      as: :json,
      params: { name: "Hello snaps" },
      headers: default_headers_auth

    snapshot = website.snapshots.find_by name: "Hello snaps"
    snapshot.change_status!("deleted")

    delete "/instances/testsite/snapshots/#{snapshot.id}",
      as: :json,
      headers: default_headers_auth

    assert_response :bad_request
  end

end
