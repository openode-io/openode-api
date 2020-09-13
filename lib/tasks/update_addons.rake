require 'rest-client'

namespace :update do
  desc ''
  task addons: :environment do
    task_name = "Task update__addons"
    Rails.logger.info "[#{task_name}] begin"

    manager = CloudProvider::Manager.instance
    addons_repository_fileroot_url = manager.application.dig(
      'addons', 'repository_fileroot_url'
    )
    addons_repository_tree_url = manager.application.dig(
      'addons', 'repository_tree_url'
    )

    repo_tree = JSON.parse(
      RestClient::Request.execute(method: :get, url: addons_repository_tree_url)
    ).dig('tree')

    repo_tree.each do |tree_item|
      next if tree_item['type'] != 'tree' || tree_item['path'].scan(%r{/}).count != 1

      dir_addon = tree_item['path']

      config_url = "#{addons_repository_fileroot_url}#{dir_addon}/config.json"
      config_content = JSON.parse(
        RestClient::Request.execute(method: :get, url: config_url)
      )

      addon = if Addon.exists?(name: config_content['name'])
                Addon.find_by(name: config_content['name'])
              else
                Addon.create!(name: config_content['name'], category: config_content['category'])
      end

      addon.name = config_content['name']
      addon.category = config_content['category']
      addon.obj = config_content
      addon.save!
    rescue StandardError => e
      Rails.logger.error("Issue update addon... #{e}")
    end
  end
end
