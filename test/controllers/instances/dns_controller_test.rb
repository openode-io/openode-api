# frozen_string_literal: true

require 'test_helper'

class DnsControllerTest < ActionDispatch::IntegrationTest
  # add alias

  test '/instances/:instance_id/add-alias with custom domain' do
    w = Website.find_by site_name: 'www.what.is'
    w.domains = ['www.what.is', 'www2.www.what.is']
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

    assert_equal w.events.length, 1
    assert_equal w.events[0].obj['title'], 'Add domain alias'
  end

  test '/instances/:instance_id/add-alias with subdomain should fail' do
    w = default_website

    post "/instances/#{w.id}/add-alias",
         as: :json,
         params: { hostname: 'www3.www.what.is' },
         headers: default_headers_auth

    assert_response :bad_request

    assert_includes response.parsed_body.to_s, "requires a custom domain"
  end

  test '/instances/:instance_id/add-alias with custom domain - forbidden' do
    w, = prepare_forbidden_test(Website::PERMISSION_PLAN)

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

    assert_equal w.events.length, 1
    assert_equal w.events[0].obj['title'], 'Delete domain alias'
  end

  test '/instances/:instance_id/del-alias with subdomain should fail' do
    w = default_website

    post "/instances/#{w.id}/del-alias",
         as: :json,
         params: { hostname: 'www3.www.what.is' },
         headers: default_headers_auth

    assert_response :bad_request

    assert_includes response.parsed_body.to_s, "requires a custom domain"
  end

  test '/instances/:instance_id/del-alias with custom domain - forbidden' do
    w, = prepare_forbidden_test(Website::PERMISSION_PLAN)

    post "/instances/#{w.site_name}/del-alias",
         as: :json,
         params: { hostname: 'www3.www.what.is' },
         headers: default_headers_auth

    assert_response :forbidden
  end

  test '/instances/:instance_id/dns get settings with configs' do
    w = Website.find_by site_name: 'www.what.is'
    w.user = default_user
    w.type = Website::TYPE_KUBERNETES
    w.domains = ['www.what.is', 'www2.www.what.is']
    w.save!

    get '/instances/www.what.is/dns',
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body['external_addr'], '127.0.0.2'
    assert_equal response.parsed_body['cname'], 'usa.openode.io'
  end
end
