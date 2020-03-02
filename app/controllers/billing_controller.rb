class BillingController < ApplicationController
  before_action do
    authorize
  end

  def orders
    attributes_to_search = %w[id content gateway]

    json(default_listing(@user.orders, attributes_to_search))
  end
end
