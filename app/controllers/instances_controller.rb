class InstancesController < ApplicationController
  MINIMUM_CLI_VERSION = '2.0.14'

  before_action :authorize

  before_action except: [:create_instance] do
    populate_website
  end

  before_action except: [:add_location] do
    populate_website_location
  end

  before_action :prepare_runner
  after_action :terminate_runner

  before_action :check_minimum_cli_version
  before_action :prepare_record_website_event
  after_action :record_website_event

  before_action only: %i[reload] do
    requires_docker_deployment
  end

  before_action only: %i[stop cmd reload] do
    requires_status_in [Website::STATUS_ONLINE]
  end

  before_action only: [:restart, :logs] do
    requires_status_in [Website::STATUS_ONLINE, Website::STATUS_OFFLINE]
  end

  before_action only: [:set_plan] do
    requires_access_to(Website::PERMISSION_PLAN)
  end

  before_action only: [:changes, :send_compressed_file, :delete_files, :cmd, :stop,
                       :reload, :erase_all, :restart] do
    requires_access_to(Website::PERMISSION_DEPLOY)
  end

  before_action only: [:destroy_instance] do
    requires_access_to(Website::PERMISSION_ROOT)
    requires_status_in [Website::STATUS_OFFLINE]
    requires_website_inactive!
  end

  before_action only: [:update] do
    requires_access_to(Website::PERMISSION_CONFIG)
  end

  api!
  def index
    json(@user.websites_with_access)
  end

  api!
  def summary
    json(@user.websites_with_access
      .map do |w|
        w_obj = w.attributes

        w_obj['location'] = w.website_locations&.first&.location
        w_obj["plan"] = w.plan
        w_obj["price"] = w.price
        w_obj["plan_name"] = w.plan_name
        w_obj["nb_collaborators"] = w.collaborators.count
        w_obj["last_deployment_id"] = w.deployments.last&.id
        w_obj["ip"] = w.first_ip
        w_obj["active"] = w.active?

        extra_storage = w.website_locations&.first&.extra_storage || 0

        if extra_storage.positive?
          w_obj["persistence"] = {
            extra_storage: extra_storage,
            storage_areas: w.storage_areas || []
          }
        end

        w_obj
      end
      .sort_by { |w| w['created_at'] }
      .reverse)
  end

  api!
  def status
    json(@website.statuses.last&.simplified_container_statuses || [])
  end

  def show
    json(@website)
  end

  def create_instance
    website = Website.create!(
      site_name: params['site_name'],
      account_type: params['account_type'],
      user: @user,
      open_source: {
        title: params['open_source_title'],
        description: params['open_source_description'],
        repository_url: params['open_source_repository']
      }
    )

    # if a location is specified, create website location
    if params['location']
      location = Location.find_by!(str_id: params['location'])
      website.add_location(location)
    end

    json(website)
  end

  api!
  def destroy_instance
    @website.destroy

    json(result: 'success')
  end

  api!
  def update
    @website.update(website_params)

    @website_event_obj = {
      title: 'update-website',
      changes: website_params
    }

    json(result: 'success')
  end

  api!
  def plan
    json(@website.plan)
  end

  api!
  def plans
    json(@website_location.available_plans)
  end

  api!
  def set_plan
    plan_id = params['plan']

    all_plans = @website_location.available_plans
    plan = all_plans.find { |p| [p[:id], p[:internal_id]].include?(plan_id) }

    validation_error!('Unavailable plan') unless plan

    @website.change_plan!(plan[:internal_id])

    @website_event_obj = {
      title: 'change-plan',
      new_value: plan[:id],
      original_value: @website.account_type
    }

    @runner&.delay&.execute([{ cmd_name: 'stop', options: { is_complex: true } }])

    json(result: 'success', msg: 'Instance will stop, make sure to redeploy it')
  end

  api!
  def changes
    validation_error!('Missing files') unless params['files']
    files_client = JSON.parse(params['files'])
    files_server = JSON.parse(@runner.execute([
                                                {
                                                  cmd_name: 'files_listing',
                                                  options: { path: @website.repo_dir }
                                                }
                                              ]).first[:result][:stdout])

    changes = Io::Dir.diff(files_client, files_server, @website.normalized_storage_areas)

    @website_event_obj = { title: 'sync-changes', changes: changes }

    json(changes)
  end

  def send_compressed_file
    file = params['file'].tempfile
    local_file = file.path
    archive_filename = params['file'].original_filename
    remote_file = "#{@website.repo_dir}#{archive_filename}"

    raise 'bad remote file' unless Io::Path.secure?(@website.repo_dir, remote_file)

    @runner.execute([
                      { cmd_name: 'ensure_remote_repository', options: { path: @website.repo_dir } }
                    ])

    @runner.upload(local_file, remote_file)

    @runner.execute([
                      { cmd_name: 'uncompress_remote_archive',
                        options: { archive_path: remote_file, repo_dir: @website.repo_dir } }
                    ])

    json(result: 'success')
  end

  def delete_files
    assert params['filesInfo'].present?

    input_files =
      if params['filesInfo'].class.name == 'String'
        JSON.parse(params['filesInfo'])
      else
        params['filesInfo']
    end

    input_files = input_files.map { |file| "#{@website.repo_dir}#{file['path']}" }
    files = Io::Path.filter_secure(@website.repo_dir, input_files)

    @runner.execute([
                      {
                        cmd_name: 'delete_files', options: {
                          files: files
                        }
                      }
                    ])

    @website_event_obj = { title: 'delete-files', files: files }

    json(result: 'success')
  end

  api!
  def cmd
    assert params['cmd'].present?

    result = @runner.execute([
                               {
                                 cmd_name: 'custom_cmd', options: {
                                   website: @website.clone,
                                   website_location: @website_location,
                                   cmd: Io::Cmd.sanitize_input_cmd(params['cmd']),
                                   service: Io::Cmd.sanitize_input_cmd(params['service'])
                                 }
                               }
                             ]).first[:result]

    json(result: result)
  end

  api!
  def stop
    @runner&.delay&.execute([{ cmd_name: 'stop', options: { is_complex: true } }])

    json(result: 'success')
  end

  api!
  def reload
    @runner.delay.execute([{ cmd_name: 'reload', options: { is_complex: true } }])
    @website_event_obj = { title: 'instance-reload' }

    json(result: 'success', msg: 'operation in progress')
  end

  # TODO: deprecate
  def docker_compose
    content = if [true, 'true'].include?(params['has_env_file'])
                DeploymentMethod::DockerCompose.default_docker_compose_file(
                  with_env_file: true
                )
              else
                DeploymentMethod::DockerCompose.default_docker_compose_file
    end

    json(
      content: content
    )
  end

  api!
  def erase_all
    return json(result: 'success') unless @website_location

    @runner.execute([
                      {
                        cmd_name: 'erase_repository_files',
                        options: { path: @website.repo_dir }
                      },

                      {
                        cmd_name: 'ensure_remote_repository',
                        options: { path: @website.repo_dir }
                      }
                    ])

    @website_event_obj = { title: 'Repository cleared (erase-all)' }

    json(result: 'success')
  end

  api!
  def logs
    nb_lines = params['nbLines'].present? ? params['nbLines'].to_i : 100

    result = if @website.online?
               # get live logs when online
               cmds = [{
                 cmd_name: 'logs',
                 options: {
                   website: @website,
                   website_location: @website_location || @website.website_locations.first,
                   nb_lines: nb_lines
                 }
               }]
               logs = @runner.execute(cmds)

               logs.first[:result][:stdout]
             else
               # when offline, print latest deployment
               latest_deployment = @website.deployments.last(10).select(&:events).last

               s_latest_deployment = "*** \nInstance offline... " \
                                     "printing latest deployment " \
                                     "(#{latest_deployment&.created_at}) ***\n\n" +
                                     latest_deployment&.humanize_events.to_s

               latest_deployment ? s_latest_deployment : "No deployment logs available."
             end

    json(logs: result)
  end

  api!
  def restart
    # run in background:
    @runner.init_execution!('Deployment')
    DeploymentMethod::Deployer.delay.run(@website_location, @runner)

    json(result: 'success', deploymentId: @runner.execution.id)
  rescue StandardError => e
    Ex::Logger.error(e, 'Issue starting deploying')
    raise e
  end

  protected

  def ensure_location
    @website_location ||= @website.website_locations.first
  end

  def requires_docker_deployment
    unless @website.type == Website::TYPE_DOCKER
      validation_error!("The instance must be of docker type.")
    end
  end

  def requires_status_in(statuses)
    unless statuses.include?(@website.status)
      validation_error!("The instance must be in status #{statuses}.")
    end
  end

  def requires_website_inactive!
    if @website.active?
      validation_error!("The instance should not be deployed and with no active storage.")
    end
  end

  def requires_location_server
    unless @website_location.andand.location_server
      validation_error!('This feature requires a server already allocated.')
    end
  end

  def requires_custom_domain
    unless @website.domain_type == 'custom_domain'
      validation_error!('This feature requires a custom domain.')
    end
  end

  def requires_access_to(permission)
    @user.can?(permission, @website)
  end

  private

  def populate_website
    if params['site_name']
      pid = params['site_name']
      @website = Website.where(site_name: pid).or(Website.where(id: pid)).first!

      unless @website.accessible_by?(@user)
        authorization_error!('Not authorized to access website')
      end
    end
  end

  def populate_website_location
    if !params['location_str_id'] && @website&.website_locations&.first
      params['location_str_id'] = @website.website_locations.first.location.str_id
    end

    if params['location_str_id']
      @location = Location.find_by str_id: params['location_str_id']

      validation_error!('That location does not exist.') unless @location

      @website_location = @website.website_locations.find_by location_id: @location.id

      validation_error!('That location does not exist for this instance.') unless @website_location

      @location_server = @website_location.location_server
    end
  end

  def check_minimum_cli_version
    if params['version']
      unless Gem::Version.new(params['version']) >= Gem::Version.new(MINIMUM_CLI_VERSION)
        validation_error!('Deprecated CLI version, please upgrade with npm i -g openode')
      end
    end
  end

  def prepare_runner
    @runner = @website_location.prepare_runner if @website_location
  end

  def terminate_runner
    @runner.terminate if @runner.present?
  end

  def prepare_record_website_event
    @website_event_obj = nil
    @website_event_objs = []
  end

  def record_website_event
    @website.create_event(@website_event_obj) if @website_event_obj

    @website_event_objs.each do |event_obj|
      @website.create_event(event_obj)
    end
  end

  def website_params
    params.require(:website).permit(
      :user_id, :crontab, open_source: {}
    )
  end
end
