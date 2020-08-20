
class OpenSourceController < ApplicationController
  api!
  def latest
    websites = Website
               .where(open_source_activated: true)
               .paginate(page: params[:page], per_page: 99)
               .order("id DESC")

    json(websites.map { |w| simplified(w) })
  end

  def project
    json(simplified(Website.find_by!(
                      site_name: params["site_name"],
                      open_source_activated: true
                    )))
  end

  protected

  def simplified(website)
    {
      id: website.id,
      status: website.status,
      site_name: website.site_name,
      hostname: website.website_locations&.first&.main_domain,
      open_source: website.open_source,
      created_at: website.created_at,
      updated_at: website.updated_at
    }
  end
end
