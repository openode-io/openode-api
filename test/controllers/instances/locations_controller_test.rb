# frozen_string_literal: true

require 'test_helper'

class LocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
  end

  test '/instances/:instance_id/locations with subdomain' do
    get '/instances/testsite/locations', as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]['id'], 'canada'
  end

  test '/instances/:instance_id/add-location fail if already exists' do
    post '/instances/testsite/add-location',
         as: :json,
         params: { location_str_id: 'canada' },
         headers: default_headers_auth

    assert_response :bad_request
  end

  test '/instances/:instance_id/add-location fail already have a location' do
    w = Website.find_by site_name: 'testsite'
    w.change_status! Website::STATUS_OFFLINE
    wl = w.website_locations.first
    wl.extra_storage = 0
    wl.save!

    post '/instances/testsite/add-location',
         as: :json,
         params: { location_str_id: 'usa' },
         headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body['error'], 'Multi location is not currently supported'
  end

  test '/instances/:instance_id/remove-location then add, with website location configs' do
    w = Website.find_by site_name: 'testsite'

    w.change_status! Website::STATUS_OFFLINE
    wl = w.website_locations.first
    wl.extra_storage = 0
    wl.save!

    location = wl.location

    post "/instances/#{w.site_name}/remove-location",
         as: :json,
         params: { location_str_id: location.str_id },
         headers: default_headers_auth

    assert_response :success

    post "/instances/#{w.site_name}/add-location",
         as: :json,
         params: { location_str_id: location.str_id },
         headers: default_headers_auth

    assert_response :success

    w.website_locations.reload
    assert_equal w.website_locations.first.location.str_id, location.str_id
  end

  test '/instances/:instance_id/add-location forbidden' do
    w, = prepare_forbidden_test(Website::PERMISSION_PLAN)

    post "/instances/#{w.site_name}/add-location",
         as: :json,
         params: { location_str_id: 'usa' },
         headers: default_headers_auth

    assert_response :forbidden
  end

  test '/instances/:instance_id/add-location happy path' do
    w = default_website
    w.change_status! Website::STATUS_OFFLINE
    w.website_locations.destroy_all

    post '/instances/testsite/add-location',
         as: :json,
         params: { location_str_id: 'canada' },
         headers: default_headers_auth

    w.reload
    w.website_locations.reload

    assert_response :success
    assert_equal w.website_locations.length, 1
    assert_equal w.website_locations[0].location.str_id, 'canada'
    assert_equal w.website_locations[0].location_server.ip, '127.0.0.1'

    assert_equal w.events.length, 1
    assert_equal w.events[0].obj['title'], 'add-location'
  end

  test '/instances/:instance_id/add-location should not if online' do
    w = default_website
    w.change_status!(Website::STATUS_ONLINE)

    post "/instances/#{w.site_name}/add-location",
         as: :json,
         params: { location_str_id: 'usa' },
         headers: default_headers_auth

    assert_response :bad_request
  end

  # remove location

  test '/instances/:instance_id/remove-location fail if no location' do
    w = default_website
    w.website_locations.destroy_all

    post '/instances/testsite/remove-location',
         as: :json,
         params: { location_str_id: 'canada' },
         headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body['error'], 'That location does not exist'
  end

  test '/instances/:instance_id/remove-location forbidden' do
    w, = prepare_forbidden_test(Website::PERMISSION_PLAN)
    wl = w.website_locations.first

    post "/instances/#{w.site_name}/remove-location",
         as: :json,
         params: { location_str_id: wl.location.str_id },
         headers: default_headers_auth

    assert_response :forbidden
  end

  test '/instances/:instance_id/remove-location should not if online' do
    w = default_website
    w.change_status!(Website::STATUS_ONLINE)
    wl = w.website_locations.first

    post "/instances/#{w.site_name}/remove-location",
         as: :json,
         params: { location_str_id: wl.location.str_id },
         headers: default_headers_auth

    assert_response :bad_request
  end

  test '/instances/:instance_id/remove-location should not if has storage' do
    w = default_website
    w.change_status!(Website::STATUS_OFFLINE)
    wl = w.website_locations.first
    wl.extra_storage = 0
    wl.change_storage!(2)

    post "/instances/#{w.site_name}/remove-location",
         as: :json,
         params: { location_str_id: wl.location.str_id },
         headers: default_headers_auth

    assert_response :bad_request
  end

  test '/instances/:instance_id/remove-location happy path' do
    w = default_website
    w.change_status!(Website::STATUS_OFFLINE)
    wl = w.website_locations.first
    wl.extra_storage = 0
    wl.save!

    post '/instances/testsite/remove-location',
         as: :json,
         params: { location_str_id: 'canada' },
         headers: default_headers_auth

    w.reload
    w.website_locations.reload

    assert_response :success

    assert_equal w.website_locations.length, 0

    assert_equal w.events.length, 1
    assert_equal w.events[0].obj['title'], 'remove-location'
  end
end
