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
end
