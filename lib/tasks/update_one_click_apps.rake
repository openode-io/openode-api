require 'rest-client'

def get_repo_file(url)
  RestClient::Request.execute(method: :get, url: url)
end

def get_repo_json(url)
  JSON.parse(get_repo_file(url))
end

namespace :update do
  desc ''
  task one_click_apps: :environment do
    task_name = "Task update__one_click_apps"
    Rails.logger.info "[#{task_name}] begin"

    manager = CloudProvider::Manager.instance
    repository_fileroot_url = manager.application.dig(
      'one_click_apps', 'repository_fileroot_url'
    )
    repository_tree_url = manager.application.dig('one_click_apps', 'repository_tree_url')

    repo_tree = get_repo_json(repository_tree_url)['tree']

    repo_tree.each do |tree_item|
      next if tree_item['type'] != 'tree' || tree_item['path'].ends_with?("config.json")

      current_dir = tree_item['path']

      base_url = "#{repository_fileroot_url}#{current_dir}/"

      config_content = get_repo_json("#{base_url}config.json")

      Rails.logger.info "[#{task_name}] Updating one click app #{base_url}"

      app = if OneClickApp.exists?(name: config_content['name'])
              OneClickApp.find_by(name: config_content['name'])
            else
              OneClickApp.create!(name: config_content['name'])
      end

      app.name = config_content['name']
      app.prepare = get_repo_file("#{base_url}prepare.rb")
      app.dockerfile = get_repo_file("#{base_url}Dockerfile")

      if config_content['logo_filename'].present?
        config_content['logo_url'] = "#{base_url}#{config_content['logo_filename']}"
      end
      app.config = config_content

      app.save!

      Rails.logger.info "[#{task_name}] Updated one click app #{base_url}"
    rescue StandardError => e
      Rails.logger.error("Issue processing template... #{e}")
    end
  end
end
