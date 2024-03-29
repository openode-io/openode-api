
TASK_NAME = "Task registry__clean"

def first_build_server_configs(build_server)
  {
    host: build_server['ip'],
    secret: {
      user: build_server['user'],
      private_key: build_server['private_key']
    }
  }
end

def deployment_method
  manager = CloudProvider::Manager.instance

  build_server_configs = first_build_server_configs(
    manager.application['docker']['build_servers'].first
  )

  runner = DeploymentMethod::Runner.new(
    Website::TYPE_GCLOUD_RUN,
    "gcloud",
    build_server_configs.merge(location: nil)
  )

  dep_method = DeploymentMethod::GcloudRun.new
  dep_method.runner = runner

  dep_method
end

def destroy_tag_image(dep_method, image_fullname, tag_obj)
  digest = tag_obj["digest"]
  path_to_delete = "#{image_fullname}@#{digest}"
  Rails.logger.info "[#{TASK_NAME}] removing image tag #{path_to_delete}"

  subcommand_del_image = "container images delete #{path_to_delete} --quiet"
  dep_method.ex("gcloud_cmd",
                website: true,
                website_location: true,
                chg_dir_workspace: false,
                subcommand: subcommand_del_image)
end

namespace :registry do
  desc ''
  task clean: :environment do
    name = TASK_NAME
    Rails.logger.info "[#{name}] begin"

    dep_method = deployment_method

    subcommand_img_list = "container images list --format json"
    images_list = JSON.parse(dep_method.ex("gcloud_cmd",
                                           website: true,
                                           website_location: true,
                                           chg_dir_workspace: false,
                                           subcommand: subcommand_img_list)[:stdout])

    images_list.each do |image_obj|
      img_fullname = image_obj["name"]

      subcommand_list_tags = "container images list-tags #{img_fullname} --format json"
      tags = JSON.parse(dep_method.ex("gcloud_cmd",
                                      website: true,
                                      website_location: true,
                                      chg_dir_workspace: false,
                                      subcommand: subcommand_list_tags)[:stdout])

      has_tags = false

      tags.each do |tag_obj|
        tag_obj["tags"].each do |tag_name|
          has_tags = true
          tag_parts = DeploymentMethod::Util::InstanceImageManager.tag_parts(tag_name)

          next unless tag_parts[:execution_id]

          execution = Execution.find_by id: tag_parts[:execution_id]

          unless execution
            Rails.logger.info "[#{name}] Should remove tag #{tag_name} for " \
                              "execution #{tag_parts[:execution_id]}"

            next if Rails.env.development?

            full_img_tag = "#{img_fullname}:#{tag_name}"
            Rails.logger.info "[#{name}] untag #{full_img_tag}"

            subcommand_untag = "container images untag #{full_img_tag} --quiet --format json"
            result = dep_method.ex("gcloud_cmd",
                                   website: true,
                                   website_location: true,
                                   chg_dir_workspace: false,
                                   subcommand: subcommand_untag)

            Rails.logger.info "[#{name}] #{result}"

            destroy_tag_image(dep_method, img_fullname, tag_obj)
          end

        rescue StandardError => e
          Ex::Logger.error(e, "[#{name}] Issue removing tag")
        end

        if tag_obj["tags"].count.zero?
          next if Rails.env.development?

          destroy_tag_image(dep_method, img_fullname, tag_obj)
        end
      end

    rescue StandardError => e
      Ex::Logger.error(e, "[#{name}] Issue removing")
    end
  end
end
