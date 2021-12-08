require 'dotenv'
require 'base64'

module DeploymentMethod
  class GcloudRun < Base
    KUBECONFIGS_BASE_PATH = "config/kubernetes/"
    CERTS_BASE_PATH = "config/certs/"
    KUBE_TMP_PATH = "/home/tmp/"
    WWW_DEPLOYMENT_LABEL = "www"
    GCLOUD_PROJECT_ID = ENV["GOOGLE_CLOUD_PROJECT"]
    GCP_CERTS_BUCKET = ENV["GCP_CERTS_BUCKET"]
    DEFAULT_MAX_INSTANCES = 5

    def initialize; end

    # verify can deploy

    def verify_can_deploy(options = {})
      super(options)
    end

    def initialization(options = {})
      super(options)
    end

    def instance_up?(_options = {})
      true
    end

    def gcloud_cmd(options = {})
      website, = get_website_fields(options)
      timeout = options[:timeout] || 400

      project_path = website.repo_dir
      "timeout #{timeout} sh -c 'cd #{project_path} && gcloud --project #{GCLOUD_PROJECT_ID} " \
      "#{options[:subcommand]}'"
    end

    def image_tag_url(options = {})
      website, = get_website_fields(options)

      tag_name = DeploymentMethod::Util::InstanceImageManager.tag_name(
        website: website,
        execution_id: runner.execution.id
      )

      "gcr.io/#{GCLOUD_PROJECT_ID}/#{website.site_name}:#{tag_name}"
    end

    def clear_certain_files_prior_build_cmd(options = {})
      website, = get_website_fields(options)
      "cd #{website.repo_dir} ; rm -f .gitignore"
    end

    def build_image(options = {})
      website, website_location = get_website_fields(options)

      parent_execution = runner.execution&.parent_execution

      if parent_execution
        return parent_execution&.obj&.dig('image_name_tag')
      elsif website.reference_website_image.present?
        return website.latest_reference_website_image_tag_address
      end

      image_url = image_tag_url(options)

      # clear some files
      ex("clear_certain_files_prior_build_cmd",
         { website: website, website_location: website_location })

      # build

      notify("info", "Preparing instance image...")

      result_build = ex("gcloud_cmd", {
                          website: website,
                          website_location: website_location,
                          subcommand: "builds submit --tag #{image_url} " \
                          "--gcs-log-dir=gs://builds_logs/"
                        })

      # retrieve the build ID, it looks like:
      # Created
      # [https://.../71a90edd-6cbb-4898-9abf-1a58319df67e]
      line_with_build = result_build[:stderr]
                        .lines.find do |line|
                          line.include?("Created [https://cloudbuild.googleapis.com/")
                        end

      if line_with_build.blank?
        raise "No created build link available"
      end

      build_id = line_with_build[line_with_build.rindex("/") + 1..line_with_build.rindex("]") - 1]

      if build_id.blank? || build_id.size <= 10
        raise "Unable to retrieve the build ID"
      end

      # save the image name tag and build ID
      save_extra_execution_attrib('image_name_tag', image_url)
      save_extra_execution_attrib('build_id', build_id)

      # retrieve the logs build
      result = ex("gcloud_cmd", {
                    website: website,
                    website_location: website_location,
                    subcommand: "builds log #{build_id}",
                    ensure_exit_code: 0
                  })

      notify("info", result[:stdout])

      raise "Unable to complete successfully the image build" if result_build[:exit_code] != 0

      image_url
    end

    def service_id(website)
      "instance-#{website.id}"
    end

    def first_safe_json(str)
      result_json = JSON.parse(str)

      result_json.length.positive? ? result_json.first : nil
    end

    def region_of(website_location)
      website_location.location_config["provider_id"]
    end

    def retrieve_logs_cmd(options = {})
      website, website_location = get_website_fields(options)
      options[:nb_lines] ||= 100

      subcommand = "logging read \"resource.labels.service_name=#{service_id(website)}\" " \
        "--format=\"value(textPayload)\" --limit #{options[:nb_lines]}"

      gcloud_cmd({
                   website: website,
                   website_location: website_location,
                   subcommand: subcommand
                 })
    end

    # returns the service if available, nil otherwise
    def retrieve_run_service(options = {})
      website, website_location = get_website_fields(options)

      result = ex("gcloud_cmd", options.merge(
                                  subcommand: "run services list " \
                                    "--region=#{region_of(website_location)} " \
                                    "--filter=\"metadata.name=#{service_id(website)}\" " \
                                    "--format=json"
                                ))

      first_safe_json(result[:stdout])
    end

    def server_file_exists_cmd(options = {})
      path = options[:path]
      "ls #{path}"
    end

    def gs_cp_cmd(options = {})
      source = options[:source]
      destination = options[:destination]

      "gsutil cp #{source} #{destination}"
    end

    def sync_file_to_gcp_storage(server_file_path, gstorage_url)
      return if ex("server_file_exists_cmd", path: server_file_path)[:exit_code] != 0

      ex("gs_cp_cmd",
         source: server_file_path,
         destination: gstorage_url)[:exit_code].zero?
    end

    def sync_certs(website, website_location)
      Rails.logger.info("Considering syncing certs for website id #{website.id}")

      website_location.obj ||= {}

      if website.certs.blank?
        website_location.obj["gcloud_ssl_cert_url"] = nil
        website_location.obj["gcloud_ssl_key_url"] = nil
        website_location.save
        return
      end

      Rails.logger.info("Syncing certs for website id #{website.id}")

      # GCP_CERTS_BUCKET
      project_path = website.repo_dir

      # SSL cert
      cert_file_path = "#{project_path}#{website.certs[:cert_path]}"
      cert_gstorage_url = "#{GCP_CERTS_BUCKET}#{website.id}.cert"

      if sync_file_to_gcp_storage(cert_file_path, cert_gstorage_url)
        website_location.obj ||= {}
        website_location.obj["gcloud_ssl_cert_url"] = cert_gstorage_url
        website_location.save
      end

      # SSL key
      cert_file_path = "#{project_path}#{website.certs[:cert_key_path]}"
      cert_gstorage_url = "#{GCP_CERTS_BUCKET}#{website.id}.key"

      if sync_file_to_gcp_storage(cert_file_path, cert_gstorage_url)
        website_location.obj ||= {}
        website_location.obj["gcloud_ssl_key_url"] = cert_gstorage_url
        website_location.save
      end
    end

    def escape_quoted_command_line(value)
      value.to_s.gsub("\"", "\\\"").gsub("'", "''")
    end

    def env_variables(website)
      variables_strings = website.env.keys.map do |variable_name|
        value = escape_quoted_command_line(website.env[variable_name])
        variable = escape_quoted_command_line(variable_name)

        "#{variable}=#{value}"
      end

      variables_strings.join(",")
    end

    def deploy(options = {})
      website, website_location = get_website_fields(options)
      image_url = options[:image_url]

      notify("info", "Deploying instance...")

      result = ex("gcloud_cmd", {
                    website: website,
                    website_location: website_location,
                    subcommand: "run deploy #{service_id(website)} --port=80 " \
          "--image #{image_url} " \
          "--platform managed --region #{region_of(website_location)} " \
          "--allow-unauthenticated --set-env-vars=\"#{env_variables(website)}\" " \
          "--memory=#{website.memory}Mi " \
          "--timeout=#{website.max_build_duration} " \
          "--max-instances=#{DEFAULT_MAX_INSTANCES} "
                  })

      notify("info", "--------------- Instance boot logs ---------------")
      logs_instance = ex_stdout(
        "retrieve_logs_cmd",
        { website: website, website_location: website_location, nb_lines: 20 }
      )
      notify("info", logs_instance)
      notify("info", "--------------------------------------------------")

      unless result[:exit_code].zero?

        result_stderr = (result[:stderr]).to_s
        url_log_index = result_stderr.downcase.index("logs url:")

        if url_log_index
          notify("error", result_stderr.slice(0..(url_log_index - 1)))
        else
          notify("error", result_stderr)
        end

        raise "Unable to deploy the instance with success"
      end

      sync_certs(website, website_location)

      notify("info", "Instance deployed successfully")
    end

    def launch(options = {})
      website, website_location = get_website_fields(options)
      simplified_options = { website: website, website_location: website_location }

      location_valid =
        website_location.valid_location_plan? && website_location.available_location?

      if website.version == "v3" && !location_valid
        raise 'Invalid location for the selected plan. Make sure to remove your current' \
          ' location and add a location available for that plan.'
      end

      image_url = build_image(options)

      deploy(options.merge(image_url: image_url))

      service = retrieve_run_service(simplified_options)

      website_location.load_balancer_synced = false
      website_location.obj ||= {}
      website_location.obj["gcloud_url"] = service["status"]&.dig("url")
      website_location.save!
    end

    # snapshot

    def make_snapshot(options = {})
      require_fields([:snapshot], options)
      website, website_location = get_website_fields(options)
      snapshot = options[:snapshot]

      # configure snapshot for gcloud
      snapshot.destination_path = snapshot.get_destination_path(".tgz")
      snapshot.url = snapshot.get_url
      snapshot.save

      latest_deployment = website.deployments.last

      raise "No latest deployment available" if latest_deployment.blank?

      latest_build_id = latest_deployment.obj["build_id"]

      # get the latest build details
      snapshot.steps << { name: 'retrieving latest build', result: latest_build_id }

      result = ex("gcloud_cmd", {
                    website: website,
                    website_location: website_location,
                    subcommand: "builds describe #{latest_build_id} --format=json"
                  })
      result_json = JSON.parse(result[:stdout])
      storage_source = result_json.dig("source", "storageSource")

      url_build = "gs://#{storage_source['bucket']}/#{storage_source['object']}"

      result_cp = ex("gs_cp_cmd",
                     source: url_build,
                     destination: snapshot.destination_path)

      raise "Unable to copy the build" unless result_cp[:exit_code].zero?

      snapshot.steps << { name: 'make archive', result: result_cp[:stdout] }

      snapshot.status = Snapshot::STATUS_SUCCEED
    rescue StandardError => e
      Ex::Logger.info(e, 'issue to make the snapshot')

      snapshot.steps << { name: 'fail to complete snapshot', result: e }
      snapshot.status = Snapshot::STATUS_FAILED
    ensure
      snapshot.save
    end

    # logs

    def logs(options = {})
      website, website_location = get_website_fields(options)
      options[:nb_lines] ||= 100

      retrieve_logs_cmd(
        website: website,
        website_location: website_location,
        nb_lines: options[:nb_lines]
      )
    end

    # stop

    def delete_service_cmd(options = {})
      website, website_location = get_website_fields(options)
      async = options[:async_argument] || "--no-async"

      gcloud_cmd({
                   website: website,
                   website_location: website_location,
                   subcommand: "run services delete #{service_id(website)} " \
          "--region #{region_of(website_location)} --quiet #{async}"
                 })
    end

    def do_stop(options = {})
      website, website_location = get_website_fields(options)
      async = options[:async_argument] || "--no-async"

      ex("delete_service_cmd",
         {
           website: website,
           website_location: website_location,
           ensure_exit_code: 0,
           default_retry_scheme: true,
           async_argument: async
         })
    end

    def hooks
      [
        GcloudRun.hook_error,
        GcloudRun.hook_verify_can_deploy,
        GcloudRun.hook_logs,
        GcloudRun.hook_finalize,
        GcloudRun.hook_finalize_done,
        GcloudRun.hook_verify_instance_up,
        GcloudRun.hook_verify_instance_up_done
      ]
    end

    def self.gcloud_run_configs
      CloudProvider::Manager.instance.first_details_of_type('gcloud_run')
    end

    def self.gcloud_run_configs_at_location(str_id)
      confs = gcloud_run_configs

      confs['locations'].find { |l| l['str_id'] == str_id }
    end

    def self.configs_at_location(str_id)
      GcloudRun.gcloud_run_configs_at_location(str_id)
    end

    def final_instance_details(opts = {})
      result = {}

      website, website_location = get_website_fields(opts)

      result['result'] = 'success'
      result['url'] = "http://#{website_location.main_domain}/"
      result['temp_backend_url'] = website_location.obj["gcloud_url"]

      if website.domain_type == 'custom_domain'
        notify('info', 'Custom domain - The DNS documentation is available at ' \
                        'https://www.openode.io/docs/platform/dns.md')

        confs_at = GcloudRun.gcloud_run_configs_at_location(website_location.location.str_id)

        result['CNAME Record'] = confs_at['cname']
      end

      result
    end

    def notify_final_instance_details(opts = {})
      get_website_fields(opts)
      final_details = final_instance_details(opts)

      notify('info', details: final_details)
    end

    def finalize(options = {})
      website, = get_website_fields(options)
      super(options)
      website.reload

      begin
        if website.online?
          notify_final_instance_details(options)
          notify("info", "Please notice that DNS propagation can take few minutes for " \
                "the main URL. The temp_backend_url can be used in the meantime.")
        else
          # stop it
          notify("info", "Stopping instance...")
          do_stop(options.merge(skip_notify_errors: true, async_argument: "--no-async"))
        end
      rescue StandardError => e
        Ex::Logger.info(e, 'Unable to finalize completely')
      end

      notify('info', "\n\n*** Final Deployment state: #{runner&.execution&.status&.upcase} ***\n")
    end
  end
end
