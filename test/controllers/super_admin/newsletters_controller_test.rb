
require 'test_helper'

class SuperAdmin::NewslettersControllerTest < ActionDispatch::IntegrationTest
  test "index with matches" do
    get '/super_admin/newsletters?search=lo newslet',
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]["title"], "Hello newsletter"
  end

  test "create with valid params" do
    n_to_create = {
      title: 'hellonn',
      recipients_type: 'custom',
      content: 'bla bla <html></html>',
      custom_recipients: ['test1@gmaill.com', 'test2@gmaill.com']
    }

    post '/super_admin/newsletters',
         as: :json,
         params: {
           newsletter: n_to_create
         },
         headers: super_admin_headers_auth

    assert_response :success

    n = Newsletter.find_by! id: response.parsed_body['id']

    assert_equal n.title, n_to_create[:title]
    assert_equal n.recipients_type, n_to_create[:recipients_type]
    assert_includes n.content, n_to_create[:content]
    assert_equal n.custom_recipients, n_to_create[:custom_recipients]
  end

  test "send" do
    Newsletter.all.each(&:destroy)

    custom_newsletter = Newsletter.create!(
      title: 'hi world.',
      content: 'hihihi.',
      recipients_type: 'custom',
      custom_recipients: ['what@gmaill.com', 'what2@gmaill.com']
    )

    post "/super_admin/newsletters/#{custom_newsletter.id}/send",
         as: :json,
         headers: super_admin_headers_auth

    assert_response :success

    custom_newsletter.reload

    assert_equal response.parsed_body, {}
    assert_equal custom_newsletter.emails_sent, custom_newsletter.custom_recipients
  end
end
