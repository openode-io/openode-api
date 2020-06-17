
namespace :registry do
  desc ''
  task clean: :environment do
    name = "Task registry__clean"
    Rails.logger.info "[#{name}] begin"

    manager = CloudProvider::Manager.instance
    image_location = manager.application.dig(
      'docker', 'images_location'
    )
    registry_type = image_location.dig('registry_impl_type')

    img_registry = DeploymentMethod::Util::ImageRegistry.instance(
      registry_type,
      registry_name: image_location.dig('repository_name')
    )

    img_registry.repositories.each do |repository|
      sleep 1 unless Rails.env.test?
      tags = img_registry.tags(repository.name)

      tags.each do |tag|
        tag_parts = DeploymentMethod::Util::InstanceImageManager.tag_parts(tag.tag)

        next unless tag_parts[:execution_id]

        execution = Execution.find_by id: tag_parts[:execution_id]

        unless execution
          Rails.logger.info "[#{name}] Should remove tag #{tag.tag} for " \
                            "execution #{tag_parts[:execution_id]}"

          next if Rails.env.development?

          img_registry.destroy_tag(repository.name, tag.tag)
        end
      end
    end
  end
end
