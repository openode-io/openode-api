require 'test_helper'

class SuperAdmin::SystemSettingsControllerTest < ActionDispatch::IntegrationTest
  test "saving a system setting" do
    post '/super_admin/support/contact',
         params: { hi: 'world' },
         as: :json,
         headers: super_admin_headers_auth

    assert_response :success

    mail_sent = ActionMailer::Base.deliveries.first
    
    assert_equal mail_sent.to[0], "info@openode.io"
    assert_equal mail_sent.subject, 'opeNode Contact'
    
    puts "mail_sent.body.raw_source -> #{mail_sent.body.raw_source.inspect}"
    assert_includes mail_sent.body.raw_source, 'world'
    #assert_equal response.parsed_body['id'], sys_setting.id
   
  end

end
