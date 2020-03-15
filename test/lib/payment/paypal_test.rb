# frozen_string_literal: true

require 'test_helper'

class PaypalTest < ActiveSupport::TestCase
  def setup; end

  test 'valid input' do
    paypal_fixture_test_path = 'test/fixtures/http/payment/paypal/paypal.json'
    content = JSON.parse(File.read(Rails.root.join(paypal_fixture_test_path)))

    result = Payment::Paypal.parse(content)

    assert_not_nil result['content']
    assert_equal result['amount'], 2.0
    assert_equal result['user_id'], 10_000
    assert_equal result['payment_status'], 'Completed'
  end

  test 'is completed?' do
    paypal_fixture_test_path = 'test/fixtures/http/payment/paypal/paypal.json'
    content = JSON.parse(File.read(Rails.root.join(paypal_fixture_test_path)))

    parsed_order = Payment::Paypal.parse(content)

    assert_equal Payment::Paypal.completed?(parsed_order), true
  end

  test 'prepare_validate_transaction_url with dummy vars' do
    vars = { 'what' => 'is', 'that' => 'asdf' }

    url = Payment::Paypal.prepare_validate_transaction_url(vars)

    expected_url =
      "https://ipnpb.paypal.com/cgi-bin/webscr?cmd=_notify-validate&what=is&that=asdf"

    assert_equal url, expected_url
  end

  test 'transaction_valid? with verified' do
    assert_equal Payment::Paypal.transaction_valid?('what' => 'is'), true
  end

  # test 'transaction_valid? with invalid' do
  #   assert_equal Payment::Paypal.transaction_valid?('invalid' => 'is'), false
  # end
end
