
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
end
