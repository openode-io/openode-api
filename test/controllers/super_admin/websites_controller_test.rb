
require 'test_helper'

class SuperAdmin::WebsitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    reset_emails
  end

  test "with matches" do
    get '/super_admin/websites?search=testsite',
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 2
    assert_equal response.parsed_body[0]["site_name"], "testsite"
    assert_equal response.parsed_body[1]["site_name"], "testsite2"
  end

  test "search by user id" do
    w = default_website
    user = w.user

    get "/super_admin/websites?search=#{user.id}",
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, user.websites.count

    all_proper_user = response.parsed_body.all? { |site| site['user_id'] == user.id }
    assert all_proper_user
  end

  test "without match" do
    get '/super_admin/websites?search=ompleteasdf',
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 0
  end

  test "GET /super_admin/websites/id" do
    w = default_website
    w.configs = {
      what: 1234
    }
    w.save!

    get "/super_admin/websites/#{w.id}",
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body['site_name'], w.site_name
    assert_equal response.parsed_body['configs']['what'], 1234
  end

  test "update_open_source_request approved" do
    w = default_website

    post "/super_admin/websites/#{w.id}/update_open_source_request",
         as: :json,
         params: {
           open_source_request: {
             status: Website::OPEN_SOURCE_STATUS_APPROVED
           }
         },
         headers: super_admin_headers_auth

    assert_response :success

    w.reload

    assert_equal w.open_source['status'], Website::OPEN_SOURCE_STATUS_APPROVED
    assert_equal w.open_source_activated, true

    mail_sent = ActionMailer::Base.deliveries.first
    assert_equal mail_sent.subject, 'opeNode open source request updated'
    assert_includes mail_sent.body.raw_source, Website::OPEN_SOURCE_STATUS_APPROVED
    assert_equal mail_sent.to, [w.user.email]
  end

  test "update_open_source_request declined" do
    w = default_website

    post "/super_admin/websites/#{w.id}/update_open_source_request",
         as: :json,
         params: {
           open_source_request: {
             status: Website::OPEN_SOURCE_STATUS_REJECTED,
             reason: 'invalid project'
           }
         },
         headers: super_admin_headers_auth

    assert_response :success

    w.reload

    assert_equal w.open_source['status'], Website::OPEN_SOURCE_STATUS_REJECTED
    assert_equal w.open_source_activated, false

    mail_sent = ActionMailer::Base.deliveries.first
    assert_equal mail_sent.subject, 'opeNode open source request updated'
    assert_includes mail_sent.body.raw_source, Website::OPEN_SOURCE_STATUS_REJECTED
    assert_includes mail_sent.body.raw_source, 'invalid project'
    assert_equal mail_sent.to, [w.user.email]
  end

  test "load balancer requiring sync" do
    w = default_website
    wl = w.website_locations.first

    wl.load_balancer_synced = false
    wl.obj = { "gcloud_url" => "https://remote.com" }
    wl.save!

    get "/super_admin/website_locations/load_balancer_requiring_sync",
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body.first["website_id"], w.id
    assert_equal response.parsed_body.first["hosts"], ["testsite.openode.io"]
    assert_equal response.parsed_body.first["backend_url"], "https://remote.com"
    assert_equal response.parsed_body.first["domain_type"], "subdomain"
  end

  test "online of type - happy path" do
    w = default_website
    wl = w.website_locations.first

    assert wl

    w.status = Website::STATUS_ONLINE
    w.type = Website::TYPE_GCLOUD_RUN
    w.version = 'v3'
    w.save(validate: false)

    res = WebsiteLocation.includes(:website).where(
      "websites.status = ? AND websites.type = ?",
      Website::STATUS_ONLINE,
      Website::TYPE_GCLOUD_RUN
    ).references(:websites)

    puts "whattt ?? #{res.reload.inspect}"

    get "/super_admin/website_locations/online/#{Website::TYPE_GCLOUD_RUN}",
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]["id"], w.id
  end

  test "load balancer requiring sync - without any" do
    get "/super_admin/website_locations/load_balancer_requiring_sync",
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success
    assert_equal response.parsed_body, []
  end

  test "update website location" do
    w = default_website
    wl = w.website_locations.first

    patch "/super_admin/website_locations/#{wl.id}",
          as: :json,
          params: {
            website_location: {
              load_balancer_synced: false
            }
          },
          headers: super_admin_headers_auth

    assert_response :success

    wl.reload

    assert_equal wl.load_balancer_synced, false
  end
end
