# frozen_string_literal: true

require 'test_helper'

class DnsControllerTest < ActionDispatch::IntegrationTest
  test '/instances/:instance_id/list-dns with subdomain should fail' do
    get '/instances/testsite/list-dns', as: :json, headers: default_headers_auth

    assert_response :bad_request
  end

  # list dns

  test '/instances/:instance_id/list-dns with custom domain' do
    w = Website.find_by site_name: 'www.what.is'
    w.domains = ['www.what.is']
    w.save!

    add_collaborator_for(default_user, w)

    get '/instances/www.what.is/list-dns', as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]['domainName'], 'www.what.is'
    assert_equal response.parsed_body[0]['type'], 'A'
    assert_equal response.parsed_body[0]['id'].present?, true
  end

  test '/instances/:instance_id/list-dns with kubernetes type should fail' do
    w = Website.find_by site_name: 'www.what.is'
    w.type = Website::TYPE_KUBERNETES
    w.domains = ['www.what.is', 'www2.www.what.is']
    w.dns = []
    w.save!

    add_collaborator_for(default_user, w, Website::PERMISSION_DNS)

    get '/instances/www.what.is/list-dns',
        as: :json,
        headers: default_headers_auth

    assert_response :bad_request
  end

  # add dns

  test '/instances/:instance_id/add-dns with subdomain should fail' do
    w = Website.find_by site_name: 'testsite'
    w.save!

    post '/instances/testsite/add-dns',
         as: :json,
         params: { domainName: 'www2.www.what.is', type: 'A', value: '127.0.0.4' },
         headers: default_headers_auth

    assert_response :bad_request
  end

  test '/instances/:instance_id/add-dns with subdomain and without server should fail' do
    w = Website.find_by site_name: 'www.what.is'
    w.domains = ['www.what.is', 'www2.www.what.is']
    w.dns = []
    w.save!
    website_location = w.website_locations.first
    website_location.location_server_id = nil
    website_location.save!

    add_collaborator_for(default_user, w)

    post '/instances/www.what.is/add-dns',
         as: :json,
         params: { domainName: 'www2.www.what.is', type: 'A', value: '127.0.0.4' },
         headers: default_headers_auth

    assert_response :bad_request
  end

  test '/instances/:instance_id/add-dns with custom domain' do
    w = Website.find_by site_name: 'www.what.is'
    w.domains = ['www.what.is', 'www2.www.what.is']
    w.dns = []
    w.save!

    add_collaborator_for(default_user, w, Website::PERMISSION_DNS)

    post '/instances/www.what.is/add-dns',
         as: :json,
         params: { domainName: 'www2.www.what.is', type: 'A', value: '127.0.0.4' },
         headers: default_headers_auth

    w.reload

    assert_response :success
    assert_equal w.dns[0]['domainName'], 'www2.www.what.is'
    assert_equal w.dns[0]['type'], 'A'
    assert_equal w.dns[0]['value'], '127.0.0.4'
  end

  test '/instances/:instance_id/add-dns with kubernetes type should fail' do
    w = Website.find_by site_name: 'www.what.is'
    w.type = Website::TYPE_KUBERNETES
    w.domains = ['www.what.is', 'www2.www.what.is']
    w.dns = []
    w.save!

    add_collaborator_for(default_user, w, Website::PERMISSION_DNS)

    post '/instances/www.what.is/add-dns',
         as: :json,
         params: { domainName: 'www2.www.what.is', type: 'A', value: '127.0.0.4' },
         headers: default_headers_auth

    assert_response :bad_request
  end

  test '/instances/:instance_id/add-dns with custom domain - no permission' do
    w, = prepare_forbidden_test(Website::PERMISSION_ALIAS)

    post "/instances/#{w.site_name}/add-dns",
         as: :json,
         params: { domainName: 'www2.www.what.is', type: 'A', value: '127.0.0.4' },
         headers: default_headers_auth

    assert_response :forbidden
  end

  # del dns

  test '/instances/:instance_id/del-dns with custom domain' do
    w = Website.find_by site_name: 'www.what.is'
    w.domains = ['www.what.is', 'www2.www.what.is']
    w.dns = []
    w.save!

    add_collaborator_for(default_user, w)

    post '/instances/www.what.is/add-dns',
         as: :json,
         params: { domainName: 'www2.www.what.is', type: 'A', value: '127.0.0.4' },
         headers: default_headers_auth

    w.events.destroy_all
    w.reload
    entry_added = w.website_locations.first.compute_dns.first

    delete "/instances/www.what.is/del-dns?id=#{entry_added['id']}",
           as: :json,
           headers: default_headers_auth

    w.reload

    assert_response :success
    assert_equal w.website_locations.first.compute_dns.length, 0

    assert_equal w.events.length, 2
    assert_equal w.events[0].obj['title'], 'DNS update'
    assert_equal w.events[0].obj['updates']['deleted'].length, 1
    assert_equal(w.events[0].obj['updates']['deleted'][0]['domainName'],
                 'www2.www.what.is')
    assert_equal w.events[0].obj['updates']['deleted'][0]['type'], 'A'
    assert_equal w.events[0].obj['updates']['deleted'][0]['value'], '127.0.0.4'
    assert_equal w.events[1].obj['title'], 'Remove DNS entry'
  end

  test '/instances/:instance_id/del-dns with custom domain without permission' do
    w, = prepare_forbidden_test(Website::PERMISSION_ALIAS)

    delete "/instances/#{w.site_name}/del-dns?id=123444",
           as: :json,
           headers: default_headers_auth

    assert_response :forbidden
  end

  test '/instances/:instance_id/del-dns with kubernetes type should fail' do
    w = Website.find_by site_name: 'www.what.is'
    w.type = Website::TYPE_KUBERNETES
    w.domains = ['www.what.is', 'www2.www.what.is']
    w.dns = []
    w.save!

    add_collaborator_for(default_user, w, Website::PERMISSION_DNS)

    delete '/instances/www.what.is/del-dns?id=123444',
           as: :json,
           headers: default_headers_auth

    assert_response :bad_request
  end

  # add alias

  test '/instances/:instance_id/add-alias with custom domain' do
    w = Website.find_by site_name: 'www.what.is'
    w.domains = ['www.what.is', 'www2.www.what.is']
    w.dns = []
    w.save!

    add_collaborator_for(default_user, w, Website::PERMISSION_ALIAS)

    post '/instances/www.what.is/add-alias',
         as: :json,
         params: { hostname: 'www3.www.what.is' },
         headers: default_headers_auth

    w.reload

    assert_response :success
    assert_equal w.domains.length, 3
    assert_equal w.domains[2], 'www3.www.what.is'

    assert_equal w.events.length, 2
    nb_created = w.events[0].obj['updates']['created'].length
    assert_equal(w.events[0].obj['updates']['created'][nb_created - 1]['domainName'],
                 'www3.www.what.is')
    assert_equal w.events[1].obj['title'], 'Add domain alias'
  end

  test '/instances/:instance_id/add-alias with custom domain - forbidden' do
    w, = prepare_forbidden_test(Website::PERMISSION_DNS)

    post "/instances/#{w.site_name}/add-alias",
         as: :json,
         params: { hostname: 'www3.www.what.is' },
         headers: default_headers_auth

    assert_response :forbidden
  end

  # del alias
  test '/instances/:instance_id/del-alias with custom domain' do
    w = Website.find_by site_name: 'www.what.is'
    w.domains = ['www.what.is', 'www2.www.what.is', 'www3.www.what.is']
    w.dns = []
    w.save!

    add_collaborator_for(default_user, w)

    post '/instances/www.what.is/del-alias',
         as: :json,
         params: { hostname: 'www3.www.what.is' },
         headers: default_headers_auth

    w.reload

    assert_response :success
    assert_equal w.domains.length, 2
    assert_equal w.domains.include?('www3.www.what.is'), false

    assert_equal w.events.length, 2
    assert_equal w.events[0].obj['title'], 'DNS update'
    assert_equal w.events[1].obj['title'], 'Delete domain alias'
  end

  test '/instances/:instance_id/del-alias with custom domain - forbidden' do
    w, = prepare_forbidden_test(Website::PERMISSION_DNS)

    post "/instances/#{w.site_name}/del-alias",
         as: :json,
         params: { hostname: 'www3.www.what.is' },
         headers: default_headers_auth

    assert_response :forbidden
  end
end
