# frozen_string_literal: true

require 'test_helper'

class LocationsTest < ActionDispatch::IntegrationTest
  setup do
  end

  test '/instances/:instance_id/stats without stats' do
    get '/instances/testsite/stats',
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['bandwidth_inbound'], []
    assert_equal response.parsed_body['bandwidth_outbound'], []
    assert_equal response.parsed_body['mem'], []
    assert_equal response.parsed_body['cpu'], []
    assert_equal response.parsed_body['disk'], []
  end

  test '/instances/:instance_id/stats with stats' do
    w = default_website

    WebsiteBandwidthDailyStat.log(w, 'inbound' => 850, 'outbound' => 100)
    WebsiteBandwidthDailyStat.log(w, 'inbound' => 101, 'outbound' => 50)

    WebsiteUtilizationLog.log(w, cpu_d: 59.0, mem_d: 150, disk_usage: 810)
    WebsiteUtilizationLog.log(w, cpu_d: 58.0, mem_d: 151, disk_usage: 811)

    get '/instances/testsite/stats',
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['bandwidth_inbound'].length, 1
    assert_equal response.parsed_body['bandwidth_inbound'][0]['value'], 951
    assert_not_nil response.parsed_body['bandwidth_inbound'][0]['date']

    assert_equal response.parsed_body['bandwidth_outbound'].length, 1
    assert_equal response.parsed_body['bandwidth_outbound'][0]['value'], 150
    assert_not_nil response.parsed_body['bandwidth_outbound'][0]['date']

    assert_equal response.parsed_body['mem'].length, 2
    assert_equal response.parsed_body['mem'][0]['value'], 150
    assert_not_nil response.parsed_body['mem'][0]['date']
    assert_equal response.parsed_body['mem'][1]['value'], 151
    assert_not_nil response.parsed_body['mem'][1]['date']

    assert_equal response.parsed_body['cpu'].length, 2
    assert_equal response.parsed_body['cpu'][0]['value'], 59
    assert_not_nil response.parsed_body['cpu'][0]['date']
    assert_equal response.parsed_body['cpu'][1]['value'], 58
    assert_not_nil response.parsed_body['cpu'][1]['date']

    assert_equal response.parsed_body['disk'].length, 2
    assert_equal response.parsed_body['disk'][0]['value'], 810
    assert_not_nil response.parsed_body['disk'][0]['date']
    assert_equal response.parsed_body['disk'][1]['value'], 811
    assert_not_nil response.parsed_body['disk'][1]['date']
  end
end
