require 'rest-client'

namespace :update do
  desc ''
  task addons: :environment do
    task_name = "Task update__addons"
    Rails.logger.info "[#{task_name}] begin"

    manager = CloudProvider::Manager.instance
    addons_repository_url = manager.application.dig(
      'addons', 'repository_url'
    )
    addons_repository_tree_url = manager.application.dig(
      'addons', 'repository_tree_url'
    )

    repo_tree = JSON.parse(
      RestClient::Request.execute(method: :get, url: addons_repository_tree_url)
    ).dig('tree')

    repo_tree.each do |tree_item|
      next if tree_item['type'] != 'tree' || tree_item['path'].scan(/\//).count != 1

      puts "itree item #{tree_item}"
      dir_addon = tree_item['path']

      puts "dir addon #{dir_addon}"
    end
  end
end
