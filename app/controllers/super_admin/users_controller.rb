class SuperAdmin::UsersController < SuperAdmin::SuperAdminController
  def index
    attributes_to_search = ["users.id", "users.email"]

    json(default_listing(User, attributes_to_search, order: "users.id DESC"))
  end
end
