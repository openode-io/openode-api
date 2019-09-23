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

  def changes
    raise ApplicationRecord::ValidationError.new("Missing files") unless params["files"]
    files_client = JSON.parse(params["files"])
    files_server = JSON.parse(@runner.execute([
      { cmd_name: "files_listing", options: { path: @website.repo_dir } }
    ]).first[:stdout])

    changes = Io::Dir.diff(files_client, files_server, @website.normalized_storage_areas)

    @website_event_obj = { title: "sync-changes", changes: changes }

    json_res(changes)
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

    json_res({ result: "success" })
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

    json_res({ result: "success" })
  end

  def cmd
    assert params["cmd"].present?
    assert params["service"].present?

    result = @runner.execute([
      {
        cmd_name: "custom_cmd", options: {
          container_id: @website.container_id,
          cmd: Io::Cmd.sanitize_input_cmd(params["cmd"]),
          service: Io::Cmd.sanitize_input_cmd(params["service"]),
        } 
      }
    ])

    puts "result #{result.inspect}"

    json_res({ result: result })
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

  def erase_all
    if ! @website_location || ! @website_location.has_location_server?
      return json_res({ result: "success" }) 
    end

    logs = @runner.execute([
      { cmd_name: "erase_repository_files", options: { path: @website.repo_dir } },
      { cmd_name: "ensure_remote_repository", options: { path: @website.repo_dir } }
    ])

    @website_event_obj = { title: "Repository cleared (erase-all)" }

    json_res({ result: "success" }) 
  end

  def logs
    nb_lines = params["nbLines"].present? ? params["nbLines"].to_i : 100

    cmds = [{ cmd_name: "logs", options: { website: @website, nb_lines: nb_lines } }]
    logs = @runner.execute(cmds)

    json_res({ logs: logs.first[:stdout] })
  end

  def restart

    json_res({ result: "success", deploymentId: 1234567 })
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
