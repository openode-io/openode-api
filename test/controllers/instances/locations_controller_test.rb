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
    post '/instances/testsite/add-location',
         as: :json,
         params: { location_str_id: 'usa' },
         headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body['error'], 'Multi location is not currently supported'
  end

  test '/instances/:instance_id/add-location forbidden' do
    w, = prepare_forbidden_test(Website::PERMISSION_DNS)

    post "/instances/#{w.site_name}/add-location",
         as: :json,
         params: { location_str_id: 'usa' },
         headers: default_headers_auth

    assert_response :forbidden
  end

  test '/instances/:instance_id/add-location happy path' do
    w = default_website
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

    assert_equal w.events.length, 2
    assert_equal w.events[0].obj['title'], 'DNS update'
    assert_equal w.events[0].obj['updates']['deleted'].length, 1
    assert_equal w.events[0].obj['updates']['deleted'][0]['domainName'], 'testsite.openode.io'
    assert_equal w.events[0].obj['updates']['deleted'][0]['type'], 'A'
    assert_equal w.events[0].obj['updates']['deleted'][0]['value'], '127.0.0.10'
    assert_equal w.events[0].obj['updates']['created'][0]['domainName'], 'testsite.openode.io'
    assert_equal w.events[0].obj['updates']['created'][0]['type'], 'A'
    assert_equal w.events[0].obj['updates']['created'][0]['value'], '127.0.0.1'
    assert_equal w.events[1].obj['title'], 'add-location'
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
    w, = prepare_forbidden_test(Website::PERMISSION_DNS)

    post "/instances/#{w.site_name}/remove-location",
         as: :json,
         params: { location_str_id: 'usa' },
         headers: default_headers_auth

    assert_response :forbidden
  end

  test '/instances/:instance_id/remove-location happy path' do
    w = default_website

    post '/instances/testsite/remove-location',
         as: :json,
         params: { location_str_id: 'canada' },
         headers: default_headers_auth

    w.reload
    w.website_locations.reload

    assert_response :success

    assert_equal w.website_locations.length, 0

    assert_equal w.events.length, 2
    assert_equal w.events[0].obj['title'], 'DNS update'
    assert_equal w.events[0].obj['updates']['created'].length, 0
    assert_equal w.events[0].obj['updates']['deleted'][0]['domainName'], 'testsite.openode.io'
    assert_equal w.events[0].obj['updates']['deleted'][0]['type'], 'A'
    assert_equal w.events[0].obj['updates']['deleted'][0]['value'], '127.0.0.10'
    assert_equal w.events[1].obj['title'], 'remove-location'
  end
end
