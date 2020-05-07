
require 'test_helper'

class AvailableLocationsControllerTest < ActionDispatch::IntegrationTest
  test '/global/available-locations' do
    get '/global/available-locations', as: :json

    assert_response :success

    canada = response.parsed_body.find { |l| l['str_id'] == 'canada' }
    assert_equal canada['str_id'], 'canada'
    assert_equal canada['full_name'], 'Montreal (Canada2)'
    assert_equal canada['country_fullname'], 'Canada2'

    usa = response.parsed_body.find { |l| l['str_id'] == 'usa' }
    assert_equal usa['str_id'], 'usa'
    assert_equal usa['full_name'], 'New York (USA)'
    assert_equal usa['country_fullname'], 'United States'
  end

  test '/global/available-locations type internal' do
    get '/global/available-locations?type=internal', as: :json

    assert_response :success

    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]['str_id'], 'canada2'
  end

  # TODO: deprecate
  test '/global/available-locations type docker' do
    get '/global/available-locations?type=docker', as: :json

    assert_response :success

    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]['str_id'], 'canada2'
  end

  test '/global/available-locations with invalid type should default to kubernetes' do
    get '/global/available-locations?type=undefined', as: :json

    assert_response :success

    canada = response.parsed_body.find { |l| l['str_id'] == 'canada' }
    assert_equal canada['str_id'], 'canada'

    usa = response.parsed_body.find { |l| l['str_id'] == 'usa' }
    assert_equal usa['str_id'], 'usa'
  end

  # ips
  test '/global/available-locations/:location/ips - happy path' do
    get '/global/available-locations/eu/ips', as: :json

    assert_response :success

    # canada = response.parsed_body
    assert_equal response.parsed_body, ['104.236.32.182']
  end
end
