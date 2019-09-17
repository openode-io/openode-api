class InstancesController < ApplicationController

  before_action :authorize
  before_action :populate_website
  before_action :populate_website_location
  before_action :prepare_runner
  after_action :record_website_event
  before_action only: [:logs] do
    requires_status_of("online")
  end

  def index
    json_res(@user.websites)
  end

  def show
    json_res(@website)
  end

  def docker_compose
    content = if params["has_env_file"]
      DeploymentMethod::DockerCompose.default_docker_compose_file({
        with_env_file: true
      })
    else
      DeploymentMethod::DockerCompose.default_docker_compose_file
    end

    json_res({
      content: content
    })
  end

  def logs
    nb_lines = params["nbLines"].present? ? params["nbLines"].to_i : 100

    cmds = [{ cmd_name: "logs", options: { website: @website, nb_lines: nb_lines } }]

    logs = @runner.execute(cmds)

    json_res({
      logs: logs.first[:stdout]
    })
  end

  protected

  def ensure_location
    if ! @website_location
      @website_location = @website.website_locations.first
    end
  end

  def requires_status_of(status)
    if @website.status != status
      msg = "The instance must be in status #{status}."
      raise ApplicationRecord::ValidationError.new(msg)
    end
  end

  def requires_cloud_plan
    if @website.is_private_cloud?
      msg = "The instance must be cloud-based for this operation."
      raise ApplicationRecord::ValidationError.new(msg)
    end
  end

  private

  def authorize
    token = request.headers["x-auth-token"] || params["token"]

    @user = User.find_by!(token: token)
  end

  def populate_website
    if params["site_name"]
      @website = Website.find_by! site_name: params["site_name"]
    end
  end

  def populate_website_location
    if params["location_str_id"]
      @location = Location.find_by! str_id: params["location_str_id"]
      @website_location = @website.website_locations.find_by! location_id: @location.id
      @location_server = @website_location.location_server
    end
  end

  def prepare_runner
    if @website_location
      @runner = @website_location.prepare_runner
    end
  end

  def record_website_event
    if @website_event_obj
      WebsiteEvent.create({ ref_id: @website.id, obj: @website_event_obj })
    end
  end
end
