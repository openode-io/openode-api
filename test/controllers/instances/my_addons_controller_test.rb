require 'test_helper'

class MyAddonsControllerTest < ActionDispatch::IntegrationTest
  test '/instances/:instance_id/addons - happy path' do
    w = default_website

    addon = Addon.last

    WebsiteAddon.create(
      website: w,
      addon: addon,
      name: 'hello-toto',
      account_type: 'second'
    )

    WebsiteAddon.create(
      website: w,
      addon: addon,
      name: 'aello-toto',
      account_type: 'second'
    )

    get "/instances/#{w.site_name}/addons",
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 2
    assert_equal response.parsed_body[0].dig('name'), 'aello-toto'
    assert_equal response.parsed_body[1].dig('name'), 'hello-toto'

    assert_equal response.parsed_body[0].dig('addon', 'id'), addon.id
    assert_equal response.parsed_body[1].dig('addon', 'id'), addon.id
  end

  test '/instances/:instance_id/addons/:id - happy path' do
    w = default_website

    addon = Addon.last

    wa = WebsiteAddon.create(
      website: w,
      addon: addon,
      name: 'hello-toto',
      account_type: 'second'
    )

    get "/instances/#{w.site_name}/addons/#{wa.id}",
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.dig('name'), wa.name
  end

  test 'POST /instances/:instance_id/addons - happy path' do
    w = default_website

    addon = Addon.last

    post "/instances/#{w.site_name}/addons",
         as: :json,
         params: {
           addon: {
             name: 'hello-world',
             account_type: 'second',
             addon_id: addon.id,
             obj: {
               env: {
                 TEST: 'asdf'
               }
             }
           }
         },
         headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body['website_id'], w.id
    assert_equal response.parsed_body['addon_id'], addon.id

    website_addon = WebsiteAddon.find(response.parsed_body['id'])

    assert_equal website_addon.obj.dig('env', 'TEST'), 'asdf'
  end

  test 'PATCH /instances/:instance_id/addons - happy path' do
    w = default_website

    addon = Addon.last

    post "/instances/#{w.site_name}/addons",
         as: :json,
         params: {
           addon: {
             name: 'hello-world',
             account_type: 'second',
             addon_id: addon.id,
             obj: {
               env: {
                 TEST: 'asdf'
               }
             }
           }
         },
         headers: default_headers_auth

    assert_response :success

    website_addon = WebsiteAddon.find(response.parsed_body['id'])

    patch "/instances/#{w.site_name}/addons/#{website_addon.id}",
          as: :json,
          params: {
            addon: {
              name: 'hello-world2',
              account_type: 'third',
              obj: {
                env: {
                  TEST: 'asdf',
                  TEST2: '1122'
                }
              }
            }
          },
          headers: default_headers_auth

    assert_response :success

    website_addon.reload

    assert_equal website_addon.name, 'hello-world2'
    assert_equal website_addon.account_type, 'third'
    assert_equal website_addon.obj.dig('env', 'TEST'), 'asdf'
    assert_equal website_addon.obj.dig('env', 'TEST2'), '1122'
  end

  test 'DELETE /instances/:instance_id/addons/:id - happy path' do
    w = default_website

    addon = Addon.last

    post "/instances/#{w.site_name}/addons",
         as: :json,
         params: {
           addon: {
             name: 'hello-world',
             account_type: 'second',
             addon_id: addon.id,
             obj: {
               env: {
                 TEST: 'asdf'
               }
             }
           }
         },
         headers: default_headers_auth

    assert_response :success

    website_addon = WebsiteAddon.find(response.parsed_body['id'])

    delete "/instances/#{w.site_name}/addons/#{website_addon.id}",
           as: :json,
           headers: default_headers_auth

    assert_response :success

    assert_nil WebsiteAddon.find_by(id: website_addon.id)
  end
end
