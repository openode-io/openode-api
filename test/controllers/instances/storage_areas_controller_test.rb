# frozen_string_literal: true

require 'test_helper'

class StorageAreasControllerTest < ActionDispatch::IntegrationTest
  test '/instances/:instance_id/storage-areas' do
    w = Website.find_by site_name: 'testsite'
    w.storage_areas = ['tmp/', 'tt/']
    w.save!
    get '/instances/testsite/storage-areas', as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body, ['tmp/', 'tt/']
  end

  test 'POST /instances/:instance_id/add-storage-area' do
    post '/instances/testsite/add-storage-area',
         as: :json,
         params: { storage_area: 'tmp/' },
         headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['result'], 'success'

    w = Website.find_by site_name: 'testsite'
    assert_equal w.storage_areas, ['tmp/']

    assert_equal w.events.count, 1
    assert_equal w.events[0].obj['title'], 'add-storage-area'
  end

  test 'POST /instances/:instance_id/add-storage-area with unsecure path' do
    post '/instances/testsite/add-storage-area',
         as: :json,
         params: { storage_area: '../tmp/' },
         headers: default_headers_auth

    assert_response :unprocessable_entity
  end

  test 'POST /instances/:instance_id/add-storage-area forbidden' do
    w, = prepare_forbidden_test(Website::PERMISSION_DNS)

    post "/instances/#{w.site_name}/add-storage-area",
         as: :json,
         params: { storage_area: 'tmp/' },
         headers: default_headers_auth

    assert_response :forbidden
  end

  test 'POST /instances/:instance_id/del-storage-area' do
    w = Website.find_by site_name: 'testsite'
    w.storage_areas = ['t1/', 't2/']
    w.save!

    post '/instances/testsite/del-storage-area',
         as: :json,
         params: { storage_area: 't2/' },
         headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['result'], 'success'

    w.reload
    assert_equal w.storage_areas, ['t1/']

    assert_equal w.events.count, 1
    assert_equal w.events[0].obj['title'], 'remove-storage-area'
  end

  test 'POST /instances/:instance_id/del-storage-area forbidden' do
    w, = prepare_forbidden_test(Website::PERMISSION_DNS)

    post "/instances/#{w.site_name}/del-storage-area",
         as: :json,
         params: { storage_area: 't2/' },
         headers: default_headers_auth

    assert_response :forbidden
  end
end
