class OrderController < ApplicationController
  def paypal
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
end
