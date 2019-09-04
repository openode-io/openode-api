
require 'test_helper'

class StorageAreasTest < ActionDispatch::IntegrationTest

  test "/instances/:instance_id/storage-areas" do
    w = Website.find_by site_name: "testsite"
    w.storage_areas = ["tmp/", "tt/"]
    w.save!
    get "/instances/testsite/storage-areas", as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body, ["tmp/", "tt/"]
  end

  test "POST /instances/:instance_id/add-storage-area" do
    post "/instances/testsite/add-storage-area",
      as: :json,
      params: { storage_area: "tmp/" },
      headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body["result"], "success"

    w = Website.find_by site_name: "testsite"
    assert_equal w.storage_areas, ["tmp/"]

    assert_equal w.events.count, 1
    assert_equal w.events[0].obj["title"], "add-storage-area"
  end

  test "POST /instances/:instance_id/add-storage-area with unsecure path" do
    post "/instances/testsite/add-storage-area",
      as: :json,
      params: { storage_area: "../tmp/" },
      headers: default_headers_auth

    assert_response :unprocessable_entity
  end

end
