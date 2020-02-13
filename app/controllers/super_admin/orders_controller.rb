class SuperAdmin::OrdersController < SuperAdmin::SuperAdminController
  def index
    attributes_to_search = ["users.email", "content", "orders.id",
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
end
