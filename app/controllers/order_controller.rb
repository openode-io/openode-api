class OrderController < ApplicationController
  def paypal
    filtered_params = filtered_order_params(params)

    unless Payment::Paypal.transaction_valid?(filtered_params)
      return json(result: 'error', msg: 'Order invalid')
    end

    parsed_order = Payment::Paypal.parse(params)

    unless Payment::Paypal.completed?(parsed_order)
      return json(result: 'error', msg: 'Order not completed')
    end

    order = Order.create!(
      user_id: parsed_order['user_id'],
      amount: parsed_order['amount'],
      payment_status: parsed_order['payment_status'],
      content: parsed_order['content']
    )

    json(result: 'ok', order_id: order.id)
  rescue StandardError => e
    Ex::Logger.error(e)
    json(result: 'error', msg: e.to_s)
  end

  private

  def filtered_order_params(params)
    all_params = params.to_unsafe_h
    keys = all_params.keys

    result = {}

    keys.each do |key|
      result[key] = all_params[key] unless %w[action controller order].include?(key)
    end

    result
  end
end
