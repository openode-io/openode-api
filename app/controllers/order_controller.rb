class OrderController < ApplicationController
  def paypal
    unless Payment::Paypal.transaction_valid?(request.raw_post)
      return json(result: 'error', msg: 'Order invalid')
    end

    order = handle_paypal_payment

    json(result: 'ok', order_id: order.id)
  rescue StandardError => e
    Ex::Logger.error(e)
    json(result: 'error', msg: e.to_s)
  end

  def handle_paypal_payment(is_subscription = false)
    parsed_order = Payment::Paypal.parse(params)

    unless Payment::Paypal.completed?(parsed_order)
      raise "Order not completed"
    end

    Order.create!(
      user_id: parsed_order['user_id'],
      amount: parsed_order['amount'],
      payment_status: parsed_order['payment_status'],
      content: parsed_order['content'],
      is_subscription: is_subscription
    )
  end

  ### subscriptions

  def paypal_subscription
    request_is_json = OrderController.paypal_subscription_json?(request.raw_post)
    request_type = request_is_json ? "webhook" : "ipn"

    send("handle_paypal_subscription_#{request_type}", params, request.raw_post)

    json(result: 'ok')
  rescue StandardError => e
    Ex::Logger.error(e)
    json(result: 'error', msg: e.to_s)
  end

  def handle_paypal_subscription_ipn(arguments, raw_post)
    unless Payment::Paypal.transaction_valid?(raw_post)
      raise "invalid ipn notification"
    end

    subscription_id = arguments['recurring_payment_id']
    paypal_subscription = paypal_api.execute(:get, "/v1/billing/subscriptions/#{subscription_id}")
    user = User.find_by(id: paypal_subscription['custom_id'])

    if params['txn_type'] == "recurring_payment" && user
      params['custom'] = user.id

      handle_paypal_payment(true)
    end

    subscription = Subscription.find_by(subscription_id: subscription_id)

    unless subscription
      Rails.logger.info("Skipping handling subscription.. no subscription")
      return
    end

    # cancel handle
    if params['txn_type'] == "recurring_payment_profile_cancel"
      Rails.logger.info("Subscription handle_paypal_subscription_ipn - attempting to cancel")
      return if subscription.cancel
      Rails.logger.info("Subscription handle_paypal_subscription_ipn - unable to cancel...")
    end


    valid_statuses = %w[APPROVED ACTIVE]

    if valid_statuses.include?(paypal_subscription['status'])
      Rails.logger.info("Subscription update, is active")
      subscription.active = true
      subscription.quantity = paypal_subscription['quantity']
    else
      Rails.logger.info("Subscription update, disabling")
      subscription.active = false
      subscription.quantity = 0
    end

    subscription.save!
  end

  def paypal_api
    api = Api::Paypal.new
    api.refresh_access_token

    api
  end

  def handle_paypal_subscription_webhook(arguments, _raw_post)
    user = User.find(arguments['resource']['custom_id'])
    subscription_id = arguments['resource']['id']

    paypal_subscription = paypal_api.execute(:get, "/v1/billing/subscriptions/#{subscription_id}")

    valid_statuses = %w[APPROVED ACTIVE]

    unless valid_statuses.include?(paypal_subscription['status'])
      Rails.logger.warn "skipping webhook, status = #{paypal_subscription['status']}"
      return
    end

    Rails.logger.info "webhook handle... status is #{paypal_subscription['status']}"

    Subscription.create!(
      user_id: user.id,
      subscription_id: subscription_id,
      quantity: paypal_subscription['quantity'],
      active: true
    )
  end

  def self.paypal_subscription_json?(raw_post)
    JSON.parse(raw_post)

    true
  rescue StandardError
    false
  end
end
