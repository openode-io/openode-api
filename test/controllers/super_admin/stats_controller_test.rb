
require 'test_helper'

class SuperAdmin::StatsControllerTest < ActionDispatch::IntegrationTest
  test "happy path" do
    CreditAction.all.each(&:destroy)

    w_custom = default_custom_domain_website
    u = w_custom.user
    u.credits = 1000
    u.save!
    CreditAction.consume!(w_custom, CreditAction::TYPE_CONSUME_PLAN, 1.25)

    w = default_website
    CreditAction.consume!(w, CreditAction::TYPE_CONSUME_PLAN, 1.25)
    CreditAction.consume!(w, CreditAction::TYPE_CONSUME_PLAN, 1.25)

    c = CreditAction.consume!(w, CreditAction::TYPE_CONSUME_PLAN, 5)
    c.created_at = Time.zone.now - 1.day
    c.save!

    c = CreditAction.consume!(w, CreditAction::TYPE_CONSUME_PLAN, 5.5)
    c.created_at = Time.zone.now - 1.day
    c.save!

    c = CreditAction.consume!(w, CreditAction::TYPE_CONSUME_PLAN, 5.5)
    c.created_at = Time.zone.now - 2.days
    c.save!

    get "/super_admin/stats/spendings",
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 3

    assert_equal response.parsed_body[0]['date'], (Time.zone.now - 2.days).strftime("%Y-%m-%d")
    assert_equal response.parsed_body[0]['value'], 5.5

    assert_equal response.parsed_body[1]['date'], (Time.zone.now - 1.day).strftime("%Y-%m-%d")
    assert_equal response.parsed_body[1]['value'], 10.5
  end

  test "generic_daily_stats - with deployments" do
    Deployment.destroy_all
    dep = Deployment.create!(status: 'success', website: default_website)

    get "/super_admin/stats/generic_daily_stats?attrib_to_sum=1&entity=Deployment&entity_method=type_dep",
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body.first['date'], DateTime.now.to_date.to_s
    assert_equal response.parsed_body.first['value'], 1
  end
end
