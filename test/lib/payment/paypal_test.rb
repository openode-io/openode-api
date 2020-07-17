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

  test 'valid input with tax' do
    paypal_fixture_test_path = 'test/fixtures/http/payment/paypal/paypal_with_tax.json'
    content = JSON.parse(File.read(Rails.root.join(paypal_fixture_test_path)))

    result = Payment::Paypal.parse(content)

    assert_not_nil result['content']
    assert_equal result['amount'], 1.85
    assert_equal result['user_id'], 10_000
    assert_equal result['payment_status'], 'Completed'
  end

  test 'is completed?' do
    paypal_fixture_test_path = 'test/fixtures/http/payment/paypal/paypal.json'
    content = JSON.parse(File.read(Rails.root.join(paypal_fixture_test_path)))

    parsed_order = Payment::Paypal.parse(content)

    assert_equal Payment::Paypal.completed?(parsed_order), true
  end

  test 'parse with malformed' do
    input = {
      "mc_gross" => "10.00",
      "protection_eligibility" => "Eligible",
      "address_status" => "confirmed",
      "payer_id" => "IIOOUUII",
      "address_street" => "Sicili\xEBboulevard 500",
      "payment_date" => "02:37:44 Apr 02, 2020 PDT",
      "payment_status" => "Completed",
      "charset" => "windows-1252",
      "address_zip" => "889 XT",
      "first_name" => "Martin",
      "option_selection1" => "800 Credits",
      "mc_fee" => "0.29",
      "address_country_code" => "NL",
      "address_name" => "XXX",
      "notify_version" => "3.9",
      "custom" => "13555"
    }

    parsed_order = Payment::Paypal.parse(input)

    assert_equal parsed_order['content']['mc_gross'], '10.00'
    assert_equal parsed_order['content']['address_street'], 'Siciliboulevard 500'
  end

  test 'transaction_valid? with verified' do
    assert_equal Payment::Paypal.transaction_valid?(""), true
  end

  # test 'transaction_valid? with invalid' do
  #   assert_equal Payment::Paypal.transaction_valid?('invalid' => 'is'), false
  # end
end
