class SuperAdmin::WebsitesController < SuperAdmin::SuperAdminController
  def index
    attributes_to_search = [
      "websites.id", "users.email", "websites.site_name", "websites.account_type",
      "websites.status"
    ]

    json(default_listing(Website, attributes_to_search, order: "websites.id DESC")
        .preload(:user)
        .joins(:user))
  end
end
