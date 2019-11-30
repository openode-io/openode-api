
namespace :locations do
  desc ''
  task populate: :environment do
    # it initialize the locations on instance, for all providers
    CloudProvider::Manager.clear_instance
    CloudProvider::Manager.instance
  end
end
