class SuperAdmin::WebsitesController < SuperAdmin::SuperAdminController
  def index
    attributes_to_search = [
      "websites.id", "users.email", "websites.site_name", "websites.account_type",
      "websites.status"
    ]
    search_for = "%#{params['search']}%"

    websites = Website
               .preload(:user)
               .joins(:user)
               .search_for(search_for, attributes_to_search)
               .paginate(page: params[:page] || 1, per_page: 99)
               .order("websites.id DESC")

    json(websites)
  end
end
