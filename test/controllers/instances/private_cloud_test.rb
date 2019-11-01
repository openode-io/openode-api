# frozen_string_literal: true

require 'test_helper'

class PrivateCloudTest < ActionDispatch::IntegrationTest
  def prepare_custom_domain_with_vultr
    website = default_website
    website.account_type = 'plan-201'
    website.site_name = 'thisisatest.com'
    website.domains = ['thisisatest.com']
    website.domain_type = 'custom_domain'
    website.cloud_type = 'private-cloud'
    website.save!
    website_location = website.website_locations.first
    website_location.location.str_id = 'alaska-6'
    website_location.location.save!

    [website, website_location]
  end

  test 'POST /instances/:instance_id/allocate' do
    website, = prepare_custom_domain_with_vultr

    post '/instances/thisisatest.com/allocate?location_str_id=alaska-6',
         as: :json,
         params: {},
         headers: default_headers_auth

    website.reload

    assert_response :success
    assert_equal response.parsed_body['status'], 'Instance creating...'
    assert_equal website.data['privateCloudInfo']['SUBID'], '30303641'
    assert_equal website.data['privateCloudInfo']['SSHKEYID'], '5da3d3a1affa7'
  end

  test 'POST /instances/:instance_id/allocate fail if already allocated' do
    website, = prepare_custom_domain_with_vultr
    website.data = { 'privateCloudInfo' => { 'SUBID' => 'asdf' } }
    website.save

    post '/instances/thisisatest.com/allocate?location_str_id=alaska-6',
         as: :json,
         params: {},
         headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['success'], 'Instance already allocated'
  end

  test 'POST /instances/:instance_id/allocate fail no credit' do
    website, = prepare_custom_domain_with_vultr
    website.user.credits = 0
    website.user.save

    post '/instances/thisisatest.com/allocate?location_str_id=alaska-6',
         as: :json,
         params: {},
         headers: default_headers_auth

    assert_response :bad_request
  end

  # apply

  test 'POST /instances/:instance_id/apply should fail if not allocated' do
    website = Website.find_by! site_name: 'testprivatecloud'
    website.data = {}
    website.save!

    post '/instances/testprivatecloud/apply?location_str_id=usa',
         as: :json,
         params: {},
         headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body.to_s, 'requires to be already allocated'
  end

  test 'POST /instances/:instance_id/apply should fail if not private cloud' do
    website = Website.find_by! site_name: 'testprivatecloud'
    website.cloud_type = 'cloud'
    website.data = {}
    website.save!

    post '/instances/testprivatecloud/apply?location_str_id=usa',
         as: :json,
         params: {},
         headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body.to_s, 'must be private cloud-based'
  end

end
