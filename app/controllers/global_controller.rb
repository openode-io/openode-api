require 'vultr'

class GlobalController < ApplicationController
  api!
  def test
    json({})
  end

  api!
  def version
    json(
      version: File.read('.version').strip
    )
  end

  api!
  def available_plans
    json(CloudProvider::Manager.instance.available_plans)
  end

  api!
  def available_plans_at
    manager = CloudProvider::Manager.instance

    json(manager.available_plans_of_type_at(params['type'], params['location_str_id']))
  end

  api!
  def available_configs
    json(Website::CONFIG_VARIABLES)
  end

  api!
  def services
    json(Status.all)
  end

  api!
  def stats
    json(
      nb_users: User.count,
      nb_deployments: Deployment.total_nb
    )
  end

  api!
  def services_down
    json(Status.with_status('down'))
  end

  api!
  def settings
    msg = nil
    notification = Notification.of_level(Notification::LEVEL_PRIORITY).first

    if notification
      msg = {
        global_msg: notification&.content,
        global_msg_class: "danger"
      }
    end

    json(msg || {})
  end
end
