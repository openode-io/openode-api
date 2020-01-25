require 'test_helper'

class SuperAdmin::SystemSettingsControllerTest < ActionDispatch::IntegrationTest
  test "send basic contact" do
    post '/super_admin/support/contact',
         params: { hi: 'world' },
         as: :json,
         headers: super_admin_headers_auth

    assert_response :success

    mail_sent = ActionMailer::Base.deliveries.last

    assert_equal mail_sent.to[0], "info@openode.io"
    assert_equal mail_sent.subject, 'opeNode Contact'

    assert_includes mail_sent.body.raw_source, 'world'
  end

  test "send contact with message" do
    post '/super_admin/support/contact',
         params: { hi: 'world', message: 'this is a message' },
         as: :json,
         headers: super_admin_headers_auth

    assert_response :success

    mail_sent = ActionMailer::Base.deliveries.last

    assert_equal mail_sent.to[0], "info@openode.io"
    assert_equal mail_sent.subject, 'opeNode Contact'

    assert_includes mail_sent.body.raw_source, "Message: this is a message"
  end
end
