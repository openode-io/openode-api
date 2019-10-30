require 'test_helper'

class OrderTest < ActiveSupport::TestCase
  test 'without unused coupon' do
    user = User.first
    credits_before = user.credits

    order = Order.create!(
      user: user,
      amount: 10.0,
      payment_status: 'Completed',
      gateway: 'paypal',
      content: { 'payment_status' => 'Completed' }
    )

    user.reload

    assert_equal user.credits, credits_before + 10 * 100
    mail_sent = ActionMailer::Base.deliveries.last

    assert_equal mail_sent.subject, "opeNode Order ##{order.id} Confirmation"
    assert_equal order.amount, 10.0
    assert_equal order.payment_status, 'Completed'
    assert_equal order.gateway, 'paypal'
  end

  test 'without used coupon' do
    user = User.first
    coupon = Coupon.first
    user.coupons = [coupon]
    user.save

    credits_before = user.credits

    order = Order.create!(
      user: user,
      amount: 10.0,
      payment_status: 'Completed',
      gateway: 'paypal',
      content: { 'payment_status' => 'Completed' }
    )

    user.reload

    assert_equal user.credits, credits_before + (10 * 100) * (1.0 + coupon.extra_ratio_rebate)
    assert_equal order.amount, 10 + 9.0
    mail_sent = ActionMailer::Base.deliveries.last

    assert_equal mail_sent.subject, "opeNode Order ##{order.id} Confirmation"
  end
end
