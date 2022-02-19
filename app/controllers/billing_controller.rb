class BillingController < ApplicationController
  before_action do
    authorize
  end

  def orders
    attributes_to_search = %w[id content gateway]

    json(default_listing(@user.orders, attributes_to_search))
  end

  def request_payment
    json(RequestOrder.create!(user: @user, amount: params["amount"].to_f,
                              provider_type: params["token"]))
  end
end
