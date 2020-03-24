class SuperAdmin::OrdersController < SuperAdmin::SuperAdminController
  def index
    attributes_to_search = ["users.id", "users.email", "content", "orders.id",
                            "payment_status", "gateway"]
    search_for = "%#{params['search']}%"

    orders = Order
             .preload(:user)
             .joins(:user)
             .search_for(search_for, attributes_to_search)
             .paginate(page: params[:page] || 1, per_page: 99)
             .order("orders.id DESC")

    json(orders.map do |o|
      attribs = o.attributes
      attribs["email"] = o.user.email
      attribs
    end)
  end

  # make custom order
  def create
    assert params['user_id']
    assert params['amount']
    assert params['payment_status']
    assert params['gateway']
    assert params['reason']

    order = Order.create!(
      user_id: params['user_id'],
      amount: params['amount'],
      payment_status: params['payment_status'],
      gateway: params['gateway'],
      content: { type: 'custom', reason: params['reason'] }
    )

    json(order)
  end
end
