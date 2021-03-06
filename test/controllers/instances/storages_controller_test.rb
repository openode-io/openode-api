# frozen_string_literal: true

require 'test_helper'

class StoragesControllerTest < ActionDispatch::IntegrationTest
  test 'POST /instances/:instance_id/increase_storage with valid info' do
    payload = { amount_gb: 2 }
    post '/instances/testsite/increase-storage?location_str_id=canada',
         params: payload, as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['result'], 'success'
    assert_equal response.parsed_body['Extra Storage (GB)'], 3

    website = Website.find_by! site_name: 'testsite'
    website_location = website.website_locations.first

    assert_equal website_location.extra_storage, 3

    assert_equal website.events.count, 1
    assert_equal website.events[0].obj['title'], 'Extra Storage modification'
    assert_equal website.events[0].obj['extra_storage_changed'], '2 GBs'
    assert_equal website.events[0].obj['total_extra_storage'], '3 GBs'
  end

  test 'POST /instances/:instance_id/increase_storage fail if no user order' do
    website = Website.find_by site_name: 'testsite'
    website.user.orders.each(&:destroy)
    payload = { amount_gb: 2 }

    post "/instances/#{website.site_name}/increase-storage?location_str_id=canada",
         params: payload, as: :json, headers: default_headers_auth

    assert_response :bad_request
  end

  test 'POST /instances/:instance_id/destroy-storage with valid info' do
    website = Website.find_by! site_name: 'testsite'
    website.type = Website::TYPE_KUBERNETES
    website.status = Website::STATUS_OFFLINE
    website.save!
    wl = website.website_locations.first
    wl.change_storage!(2)

    runner = prepare_kubernetes_runner(website, wl)

    kubernetes_method = runner.get_execution_method

    cmd = kubernetes_method.kubectl(
      website_location: wl,
      with_namespace: true,
      s_arguments: "delete pvc main-pvc"
    )

    prepare_ssh_session(cmd, "deleted.")

    assert_scripted do
      begin_ssh

      post '/instances/testsite/destroy-storage?location_str_id=canada',
           params: {}, as: :json, headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body['result'], 'success'
      assert_equal response.parsed_body['Extra Storage (GB)'], 0

      website.reload
      website_location = website.website_locations.first

      assert_equal website_location.extra_storage, 0

      assert_equal website.events.count, 2
      assert_equal website.events[0].obj['title'], 'Extra Storage modification'
      assert_equal website.events[0].obj['extra_storage_changed'], '-3 GBs'
      assert_equal website.events[0].obj['total_extra_storage'], '0 GBs'
      assert_equal website.events[1].obj['title'], 'Destroy storage'

      last_exec = website.executions.last

      assert_equal last_exec.result['steps'][0]['cmd_name'], 'destroy_storage_cmd'
      assert_equal last_exec.result['steps'][0]['result']['stdout'], 'deleted.'
    end
  end

  test 'POST /instances/:instance_id/destroy-storage if online should fail' do
    website = Website.find_by! site_name: 'testsite'
    website.type = Website::TYPE_KUBERNETES
    website.status = Website::STATUS_ONLINE
    website.save!
    wl = website.website_locations.first
    wl.change_storage!(2)

    post '/instances/testsite/destroy-storage?location_str_id=canada',
         params: {}, as: :json, headers: default_headers_auth

    assert_response :bad_request
  end

  test 'POST /instances/:instance_id/increase_storage with negative gb' do
    payload = { amount_gb: -2 }
    post '/instances/testsite/increase-storage?location_str_id=canada',
         params: payload, as: :json, headers: default_headers_auth

    assert_response :bad_request
    assert response.parsed_body['error'].include?('must be positive')
  end

  test 'POST /instances/:instance_id/increase_storage with too large extra storage' do
    payload = { amount_gb: 10 }
    post '/instances/testsite/increase-storage?location_str_id=canada',
         params: payload, as: :json, headers: default_headers_auth

    assert_response :unprocessable_entity
    assert response.parsed_body['error'].include?('Extra storage')
  end

  test 'GET /instances/:instance_id/storage with website location' do
    w = Website.find_by site_name: 'testsite'
    w.storage_areas = ['/home1']
    w.save

    get '/instances/testsite/storage',
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body['extra_storage'], 1
    assert_equal response.parsed_body['storage_areas'], ['/home1']
  end

  test 'GET /instances/:instance_id/storage without website location' do
    w = Website.find_by site_name: 'testsite'
    w.storage_areas = ['/home1']
    w.save

    w.website_locations.each(&:destroy)

    get '/instances/testsite/storage',
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body['extra_storage'], 0
    assert_equal response.parsed_body['storage_areas'], ['/home1']
  end
end
