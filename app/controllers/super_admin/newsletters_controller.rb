class SuperAdmin::NewslettersController < SuperAdmin::SuperAdminController
  def index
    attributes_to_search = %w[title recipients_type content custom_recipients]

    json(default_listing(Newsletter, attributes_to_search))
  end

  def create
    custom_recipients = params['newsletter']['custom_recipients']
    json(Newsletter.create!(newsletter_params.merge(custom_recipients: custom_recipients)))
  end

  protected

  def newsletter_params
    params.require(:newsletter)
          .permit(:title, :recipients_type, :content, :custom_recipients)
  end
end
