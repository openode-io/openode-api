class SuperAdmin::NewslettersController < SuperAdmin::SuperAdminController
  def index
    attributes_to_search = %w[title recipients_type content custom_recipients]

    json(default_listing(Newsletter, attributes_to_search))
  end
end
