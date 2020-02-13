class SuperAdmin::UsersController < SuperAdmin::SuperAdminController
  def index
    attributes_to_search = ["users.id", "users.email"]
    search_for = "%#{params['search']}%"

    users = User
            .search_for(search_for, attributes_to_search)
            .paginate(page: params[:page] || 1, per_page: 99)
            .order("users.id DESC")

    json(users)
  end
end
