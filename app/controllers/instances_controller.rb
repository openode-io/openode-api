class InstancesController < ApplicationController

  MINIMUM_CLI_VERSION = "2.0.14"

  before_action :authorize
  before_action :populate_website
  before_action :populate_website_location
  before_action :prepare_runner
  after_action :terminate_runner

  before_action only: [:restart] do
    requires_minimum_cli_version
  end

  before_action :check_minimum_cli_version
  after_action :record_website_event

  before_action only: [:logs, :cmd] do
    requires_status_in [Website::STATUS_ONLINE]
  end

  before_action only: [:restart] do
    requires_status_in [Website::STATUS_ONLINE, Website::STATUS_OFFLINE]
  end

  def index
    json(@user.websites)
  end

  def show
    json(@website)
  end

  def plan
    json(@website.plan)
  end

  def plans
    json(@website_location.available_plans)
  end

  def changes
    raise ApplicationRecord::ValidationError.new("Missing files") unless params["files"]
    files_client = JSON.parse(params["files"])
    files_server = JSON.parse(@runner.execute([
      { cmd_name: "files_listing", options: { path: @website.repo_dir } }
    ]).first[:stdout])

    changes = Io::Dir.diff(files_client, files_server, @website.normalized_storage_areas)

    @website_event_obj = { title: "sync-changes", changes: changes }

    json(changes)
  end

  def send_compressed_file
    file = params["file"].tempfile
    local_file = file.path
    archive_filename = params["file"].original_filename
    remote_file = "#{@website.repo_dir}#{archive_filename}"

    raise "bad remote file" unless Io::Path.is_secure?(@website.repo_dir, remote_file)

    @runner.execute([
      { cmd_name: "ensure_remote_repository", options: { path: @website.repo_dir } }
    ])

    @runner.upload(local_file, remote_file)

    @runner.execute([
      { cmd_name: "uncompress_remote_archive", 
        options: { archive_path: remote_file, repo_dir: @website.repo_dir }
      }
    ])

    json({ result: "success" })
  end

  def delete_files
    assert params["filesInfo"].present?
    input_files = 
      params["filesInfo"].class.name == "String" ? JSON.parse(params["filesInfo"]) : params["filesInfo"]

    input_files = input_files.map { |file| "#{@website.repo_dir}#{file["path"]}" }
    files = Io::Path.filter_secure(@website.repo_dir, input_files) 

    @runner.execute([
      {
        cmd_name: "delete_files", options: { 
          files: files
        } 
      }
    ])

    @website_event_obj = { title: "delete-files", files: files }

    json({ result: "success" })
  end

  def cmd
    assert params["cmd"].present?
    assert params["service"].present?

    result = @runner.execute([
      {
        cmd_name: "custom_cmd", options: {
          website: @website.clone,
          cmd: Io::Cmd.sanitize_input_cmd(params["cmd"]),
          service: Io::Cmd.sanitize_input_cmd(params["service"]),
        } 
      }
    ]).first

    json({ result: result })
  end

  def stop

    # TODO

    @runner.execute([
      {
        cmd_name: "stop", options: {
          website: @website.clone
        } 
      }
    ])

    # change the status
    @website.change_status!(Website::STATUS_OFFLINE)

    json({ result: "success" })
  end

  def docker_compose
    content = if params["has_env_file"]
      DeploymentMethod::DockerCompose.default_docker_compose_file({
        with_env_file: true
      })
    else
      DeploymentMethod::DockerCompose.default_docker_compose_file
    end

    json({
      content: content
    })
  end

  def erase_all
    if ! @website_location || ! @website_location.has_location_server?
      return json({ result: "success" }) 
    end

    logs = @runner.execute([
      { cmd_name: "erase_repository_files", options: { path: @website.repo_dir } },
      { cmd_name: "ensure_remote_repository", options: { path: @website.repo_dir } }
    ])

    @website_event_obj = { title: "Repository cleared (erase-all)" }

    json({ result: "success" }) 
  end

  def logs
    nb_lines = params["nbLines"].present? ? params["nbLines"].to_i : 100

    cmds = [{ cmd_name: "logs", options: { website: @website, nb_lines: nb_lines } }]
    logs = @runner.execute(cmds)

    json({ logs: logs.first[:stdout] })
  end

  def restart
    # TODO init deployment model


    # run in background:
    @runner.execute([
      {
        cmd_name: "verify_can_deploy", options: { is_complex: true }
      },
      { 
        cmd_name: "initialization", options: { is_complex: true }
      },
      {
        cmd_name: "launch", options: { is_complex: true }
      },
      {
        cmd_name: "verify_instance_up", options: { is_complex: true }
      }
    ])

    @runner.execute([
      {
        cmd_name: "finalize", options: { is_complex: true }
      }
    ])

    json({ result: "success", deploymentId: 1234567 })

  rescue => ex
    logger.error("Issue deploying, #{ex}")
    raise ex
  end

  protected

  def ensure_location
    if ! @website_location
      @website_location = @website.website_locations.first
    end
  end

  def requires_status_in(statuses)
    unless statuses.include?(@website.status)
      msg = "The instance must be in status #{statuses}."
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

  def requires_minimum_cli_version
    unless params["version"].present?
      params["version"] = "0.0.0" # dummy low version
    end
  end

  def check_minimum_cli_version
    if params["version"]
      unless Gem::Version.new(params["version"]) >= Gem::Version.new(MINIMUM_CLI_VERSION)
        cmd = "Deprecated CLI version, please upgrade with npm i -g openode"
        raise ApplicationRecord::ValidationError.new(cmd)
      end
    end
  end

  def prepare_runner
    if @website_location
      @runner = @website_location.prepare_runner
    end
  end

  def terminate_runner
    @runner.terminate if @runner.present?
  end

  def record_website_event
    if @website_event_obj
      WebsiteEvent.create({ ref_id: @website.id, obj: @website_event_obj })
    end
  end
end
