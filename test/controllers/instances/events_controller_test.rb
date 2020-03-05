require 'test_helper'

class EventsControllerTest < ActionDispatch::IntegrationTest
  test '/instances/:instance_id/events' do
    w = default_website

    WebsiteEvent.create(
      ref_id: w.id,
      obj: {
        title: 'test'
      }
    )

    get "/instances/#{w.site_name}/events/",
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]['ref_id'], w.id
    assert_equal response.parsed_body[0]['obj']['title'], 'test'
  end

  test '/instances/:instance_id/events/id - exists' do
    w = default_website
    event = WebsiteEvent.create(
      ref_id: w.id,
      obj: {
        title: 'test'
      }
    )

    get "/instances/#{w.site_name}/events/#{event.id}",
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['id'], event.id
  end
end
