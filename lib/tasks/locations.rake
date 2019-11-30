
namespace :locations do
  desc ''
  task populate: :environment do
    name = "Task locations:populate"
    Rails.logger.info "[#{name}] begin"

    # it initialize the locations on instance, for all providers
    CloudProvider::Manager.clear_instance
    CloudProvider::Manager.instance
  end
end
