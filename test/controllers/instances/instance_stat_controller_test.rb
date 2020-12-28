# frozen_string_literal: true

require 'test_helper'
require 'test_kubernetes_helper'

class LocationsTest < ActionDispatch::IntegrationTest
  def setup
    @website = default_kube_website
    @website_location = @website.website_locations.first
  end

  def prepare_kubernetes_method(website, website_location)
    runner = prepare_kubernetes_runner(website, website_location)

    @kubernetes_method = runner.get_execution_method
  end

  test '/instances/:instance_id/stats with stats' do
    prepare_kubernetes_method(@website, @website_location)

    cmd_top_pods = @kubernetes_method.kubectl(
      website_location: @website_location,
      with_namespace: true,
      s_arguments: " top pods "
    )

    expected = "NAME                             CPU(cores)   MEMORY(bytes)   \n" \
                "www-deployment-9645b55d5-lkmbn   1m           31Mi"
    prepare_ssh_session(cmd_top_pods, expected)

    assert_scripted do
      begin_ssh

      get "/instances/#{@website.id}/stats",
          as: :json,
          headers: default_headers_auth

      assert_response :success
      expected_response = {
        "top" => [
          {
            "service" => "www-deployment-9645b55d5-lkmbn",
            "cpu_raw" => "1m",
            "memory_raw" => "31Mi"
          }
        ]
      }

      assert_equal response.parsed_body, expected_response
    end
  end

  test '/instances/:instance_id/stats/spendings with stats' do
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

    get "/instances/#{w.site_name}/stats/spendings",
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 3

    assert_equal response.parsed_body[0]['date'], (Time.zone.now - 2.days).strftime("%Y-%m-%d")
    assert_equal response.parsed_body[0]['value'], 5.5

    assert_equal response.parsed_body[1]['date'], (Time.zone.now - 1.day).strftime("%Y-%m-%d")
    assert_equal response.parsed_body[1]['value'], 10.5

    assert_equal response.parsed_body[2]['date'], Time.zone.now.strftime("%Y-%m-%d")
    assert_equal response.parsed_body[2]['value'], 2.5
  end

  test '/instances/:instance_id/stats/spendings without stats' do
    CreditAction.all.each(&:destroy)

    w = default_website

    get "/instances/#{w.site_name}/stats/spendings",
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 0
  end

  # network
  test '/instances/:instance_id/stats/network - happy path' do
    WebsiteBandwidthDailyStat.all.each(&:destroy)

    w = default_website

    WebsiteBandwidthDailyStat.create(
      website: w,
      obj: {
        "rcv_bytes" => 100.0,
        "tx_bytes" => 10.0
      },
      created_at: Time.zone.now - 1.day
    )

    WebsiteBandwidthDailyStat.create(
      website: w,
      obj: {
        "rcv_bytes" => 102.0,
        "tx_bytes" => 12.0
      }
    )

    get "/instances/#{w.site_name}/stats/network",
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 2
    assert_equal response.parsed_body[0]['obj']['rcv_bytes'], 100.0
    assert_equal response.parsed_body[0]['obj']['tx_bytes'], 10.0
    assert_equal response.parsed_body[1]['obj']['rcv_bytes'], 102.0
    assert_equal response.parsed_body[1]['obj']['tx_bytes'], 12.0
  end
end
