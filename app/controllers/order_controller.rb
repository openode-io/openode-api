class OrderController < ApplicationController
  def paypal
    parsed_order = Payment::Paypal.parse(params)

    unless Payment::Paypal.completed?(parsed_order)
      return json(result: 'error', msg: 'Order not completed')
    end

    json({})
  rescue StandardError => e
    Ex::Logger.error(e)
    json(result: 'error', msg: e.to_s)
  end
end
