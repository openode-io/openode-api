
namespace :build_clean do
  desc ''
  task synced_files: :environment do
    name = "Task build_clean__synced_files"
    Rails.logger.info "[#{name}] begin"

    manager = CloudProvider::Manager.instance

    manager.application['docker']['build_servers'].each do |build_server|
      configs = {
        host: build_server['ip'],
        secret: {
          user: build_server['user'],
          private_key: build_server['private_key']
        }
      }

      runner = DeploymentMethod::Runner.new(Website::TYPE_KUBERNETES, "cloud", configs)

      cmd_user_ids = "ls #{Website::REPOS_BASE_DIR}"

      user_ids = runner.execute_raw_ssh(cmd_user_ids)
                       .first[:stdout]
                       .lines
                       .map(&:strip)
                       .select { |item| item.to_i.to_s == item.to_s }

      folders_to_remove = []

      user_ids.each do |user_id|
        user = User.find_by id: user_id

        if !user || user.websites.count.zero?
          folders_to_remove << "#{Website::REPOS_BASE_DIR}#{user_id}/"
          next
        end

        user.websites.each do |website|
          last_deployment = website.deployments.last

          if !last_deployment || (Date.current - last_deployment.created_at.to_date).to_i > 1
            folders_to_remove << "#{Website::REPOS_BASE_DIR}#{user_id}/#{website.site_name}/"
          end
        end
      end

      folders_to_remove.each do |folder_to_remove|
        cmd_rm = "rm -rf #{folder_to_remove}"
        Rails.logger.info "[#{name}] #{cmd_rm}"

        runner.execute_raw_ssh(cmd_rm)
      end
    end
  end
end
