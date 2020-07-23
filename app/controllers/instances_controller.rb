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

  INSTANCE_SUMMARY_WITH_DESC = "List of extra fields to include, comma separated. " \
                              "Supported: env, collaborators, events, last_deployment"

  def summarize_website(website, extras = [])
    w = website
    w_obj = w.attributes

    w_obj['location'] = w.website_locations&.first&.location
    w_obj['hostname'] = w.website_locations&.first&.main_domain
    w_obj["plan"] = w.plan
    w_obj["price"] = w.price
    w_obj["plan_name"] = w.plan_name
    w_obj["nb_collaborators"] = w.collaborators.count
    w_obj["last_deployment_id"] = w.deployments.last&.id
    w_obj["ip"] = w.first_ip
    w_obj["active"] = w.active?
    w_obj["out_of_memory_detected"] = w.recent_out_of_memory_detected?

    extra_storage = w.website_locations&.first&.extra_storage || 0

    if extra_storage.positive?
      w_obj["persistence"] = {
        extra_storage: extra_storage,
        storage_areas: w.storage_areas || []
      }
    end

    # conditional extra fields
    w_obj["env"] = (w.env || {}) if extras.include?('env')
    w_obj["collaborators"] = w.pretty_collaborators_h if extras.include?('collaborators')
    w_obj["events"] = w.events.last(10) if extras.include?('events')
    w_obj["last_deployment"] = w.deployments.last if extras.include?('last_deployment')

    w_obj
  end

  def extra_fields_summary(with_param)
    with_param&.split(',') || []
  end

  api :GET, 'instances/summary'
  description 'List instances summary.'
  param :with, String, desc: INSTANCE_SUMMARY_WITH_DESC,
                       required: false
  param :search, String, desc: "Filter based on the site_name.", required: false
  def summary
    extras = extra_fields_summary(params[:with])

    json(@user.websites_with_access
      .select { |w| params[:search] ? w.site_name.include?(params[:search]) : true }
      .map do |w|
        summarize_website(w, extras)
      end
      .sort_by { |w| w['created_at'] }
      .reverse)
  end

  api :GET, 'instances/:id/summary'
  description 'Instance summary.'
  param :with, String, desc: INSTANCE_SUMMARY_WITH_DESC,
                       required: false
  def instance_summary
    extras = extra_fields_summary(params[:with])

    json(summarize_website(@website, extras))
  end

  api!
  def status
    json(@website.statuses.last&.obj || [])
  end

  api :GET, 'instances/:id/routes'
  description 'Returns the routes from the current site to all available sites.'
  returns code: 200,
          desc: "Hash following this format: { site_name: { host, protocol, type } }"
  def routes
    websites_with_access = @user.websites_with_access
    sites_ids = websites_with_access.map(&:id)
    website_locations = WebsiteLocation.where(website_id: sites_ids)

    wls_lookup = {}

    website_locations.each do |wl|
      wls_lookup[wl.website_id] = wl
    end

    result = {}
    website_location = @website.website_locations.first

    websites_with_access.each do |w|
      wl = wls_lookup[w.id]

      same_location = website_location&.location == wl&.location
      has_cert = w.subdomain? || (w.custom_domain? && w.certs.present?)

      result[w.site_name] = {
        host: same_location ? wl&.cluster_ip : wl&.main_domain,
        protocol: same_location || !has_cert ? 'http' : 'https',
        type: same_location ? 'private_ip' : 'hostname'
      }
    end

    json(result)
  end

  def show
    json(@website)
  end

  api :POST, 'instances/create'
  description 'To be functional, a location needs to be added also. See the Location section.'
  param :site_name, String, desc: 'Instance site name. ' \
                                  '<site_name>.openode.io for subdomains and ' \
                                  'domain for custom domains.', required: true
  param :account_type, String, desc: 'Plan internal id. Use /global/available-plans to ' \
                                      'get the list.', required: false
  def create_instance
    plan = Website.plan_of(params['account_type'])

    website = Website.create!(
      site_name: params['site_name'],
      account_type: plan&.dig(:internal_id),
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

  api :POST, 'instances/:id/crontab'
  description 'Update the crontab given a list of lines.'
  param :crontab, Array, desc: 'Array of strings, one line per item.', required: true
  def update_crontab
    lines = params[:crontab] || []
    @website.crontab = lines.join("\n")
    @website.save!

    @website_event_obj = {
      title: 'update-crontab',
      new_crontab: @website.crontab
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

    plan = Website.plan_of(plan_id)

    validation_error!('Unavailable plan') unless plan

    orig_account_type = @website.account_type
    @website.change_plan!(plan[:internal_id])

    @website_event_obj = {
      title: 'change-plan',
      new_value: plan[:id],
      original_value: Website.plan_of(orig_account_type).dig(:id)
    }

    process_reload_latest_deployment if @website.online?

    json(result: 'success')
  end

  api!
  def changes
    validation_error!('Missing files') unless params['files']

    changes = if @website.reference_website_image.present?
                []
              else
                files_client = JSON.parse(params['files'])
                files_server = JSON.parse(@runner.execute([
                                                            {
                                                              cmd_name: 'files_listing',
                                                              options: { path: @website.repo_dir }
                                                            }
                                                          ]).first[:result][:stdout])

                Io::Dir.diff(files_client, files_server, @website.normalized_storage_areas)
    end

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

    @website_event_obj = { title: 'instance-stop' }

    json(result: 'success')
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

  def deployment_response(args = {})
    {
      result: 'success',
      website: {
        id: @website.id,
        site_name: @website.site_name
      }
    }.merge(args)
  end

  api :POST, 'instances/:id/restart'
  description 'Rebuild and spawn the instance.'
  param :parent_execution_id, String, desc: 'Rollback to parent_execution_id', required: false
  def restart
    # run in background:
    @runner.init_execution!('Deployment', params)
    DeploymentMethod::Deployer.delay.run(@website_location, @runner)

    @website_event_obj = {
      title: 'instance-restart',
      deployment_id: @runner.execution.id
    }

    json(
      deployment_response(deploymentId: @runner.execution.id)
    )
  rescue StandardError => e
    Ex::Logger.error(e, 'Issue starting deploying')
    raise e
  end

  def process_reload_latest_deployment
    latest_deployment_id = @website.deployments.success.last&.id

    if latest_deployment_id
      params['parent_execution_id'] = latest_deployment_id
      process_reload
    end
  end

  def process_reload
    @runner.init_execution!('Deployment', params)
    execution = @runner.execution
    execution.status = Execution::STATUS_RUNNING
    execution.save

    @runner.delay.execute([{ cmd_name: 'reload', options: { is_complex: true } }])

    @website_event_obj = { title: 'instance-reload', deployment_id: @runner.execution&.id }
  end

  api!
  def reload
    process_reload

    json(
      deployment_response(deploymentId: @runner.execution&.id)
    )
  end

  protected

  def ensure_location
    @website_location ||= @website.website_locations.first
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
      :user_id, :alerts, :crontab, open_source: {}, alerts: []
    )
  end
end
