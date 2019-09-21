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
    puts "paramss #{file.inspect}"

    #Parameters: {"info"=>"{\"path\":\"009de841ac96841fd375d2f904354b27.zip\"}", "version"=>"2.0.14", "location_str_id"=>"canada", "file"=>#<ActionDispatch::Http::UploadedFile:0x00007f2a004177e8 @tempfile=#<Tempfile:/tmp/RackMultipart20190921-11527-cm6855.zip>, @original_filename="009de841ac96841fd375d2f904354b27.zip", @content_type="application/zip", @headers="Content-Disposition: form-data; name=\"file\"; filename=\"009de841ac96841fd375d2f904354b27.zip\"\r\nContent-Type: application/zip\r\n">, "site_name"=>"myprettytest.com"}


    json_res({})
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
      { cmd_name: "initialize_repository", options: { path: @website.repo_dir } }
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
