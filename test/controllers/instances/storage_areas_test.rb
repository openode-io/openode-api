
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

end
