require 'vultr'

class GlobalController < ApplicationController
  api!
  def test
    json({})
  end

  api!
  def recently_auth
    result = User.exists?(latest_request_ip: params["ip"])

    json(result: result)
  end

  api!
  def version
    json(
      version: File.read('.version').strip
    )
  end

  api!
  def status_job_queues
    nb_jobs = System::Global.queues_len

    is_too_full = nb_jobs > Deployment::MAX_CONCURRENCY + 5

    json({}, is_too_full ? :internal_server_error : :ok)
  end

  api!
  def available_plans
    plans = CloudProvider::Manager.instance.available_plans
    json(plans)
  end

  api!
  def available_plans_gcloud_run
    plans = CloudProvider::GcloudRun.new.plans
    json(plans)
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

  PERMITTED_TYPE_LISTS = [
    'Website::ALERT_TYPES',
    'OneClickApps'
  ].freeze
  api :GET, 'global/type-lists/:type'
  description 'Type lists.'
  param :type, String, desc: "Permitted values: #{PERMITTED_TYPE_LISTS}",
                       required: true
  def type_lists
    unless GlobalController::PERMITTED_TYPE_LISTS.include?(params[:type])
      validation_error!('Invalid type')
    end

    types = {
      "Website::ALERT_TYPES" => "Website::ALERT_TYPES",
      "OneClickApps" => "OneClickApp.all.order(:name)"
    }

    json(eval(types[params[:type]]))
  end
end
