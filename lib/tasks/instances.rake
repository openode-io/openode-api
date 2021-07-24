
def get_openode_api(website)
  Api::Openode.new(token: website.user.token)
end

def post_instance(website, path_api, title)
  openode_api = get_openode_api(website)

  website.website_locations.each do |website_location|
    result_api_call = openode_api.execute(
      :post, path_api,
      params: { 'location_str_id' => website_location.location.str_id }
    )

    website.create_event(title: title,
                         api_result: result_api_call)
  end
end

def stop_instance(website, title)
  path_api = "/instances/#{website.site_name}/stop"

  post_instance(website, path_api, title)
end

namespace :instances do
  desc ''
  task :restart, [:instance_id] => [:environment] do |_t, args|
    name = "Task instances__restart #{args.inspect}"
    Rails.logger.info "[#{name}] restart starting..."

    website = Website.find_by(id: args[:instance_id]) ||
              Website.find_by(site_name: args[:instance_id])

    raise "Website not found" if website.blank?

    begin
      result = stop_instance(website, "Stopped due to maintenance")
      Rails.logger.info "[#{name}] Stopped #{result.inspect}"
    rescue StandardError => e
      Rails.logger.info "[#{name}] failed to stop #{e.inspect}"
    end

    Rails.logger.info "waiting to be stopped..."
    sleep 30

    path_executions = "/instances/#{website.id}/executions/list" \
                      "/Deployment/?status=success"
    latest_exec = get_openode_api(website).execute(:get, path_executions).first

    if latest_exec.present?
      Rails.logger.info "[#{name}] Restarting with exec id #{latest_exec['id']}"
      path_restart = "/instances/#{website.id}/restart" \
                      "?parent_execution_id=#{latest_exec['id']}"

      result = get_openode_api(website).execute(:post, path_restart)
      Rails.logger.info "[#{name}] restart: #{result.inspect}"
    end
  end
end
