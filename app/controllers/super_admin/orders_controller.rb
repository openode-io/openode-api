class SuperAdmin::OrdersController < SuperAdmin::SuperAdminController
  def index
    search_for = "%#{params['search']}%"

    orders = Order
             .preload(:user)
             .joins(:user)
             .where(" users.email LIKE ? OR " \
                      " content LIKE ? OR " \
                      " payment_status LIKE ? OR " \
                      " gateway LIKE ? ", search_for, search_for, search_for, search_for)
             .paginate(page: params[:page] || 1, per_page: 99)
             .order("id DESC")

    json(orders.map do |o|
      attribs = o.attributes
      attribs["email"] = o.user.email
      attribs
    end
    )
  end
end
