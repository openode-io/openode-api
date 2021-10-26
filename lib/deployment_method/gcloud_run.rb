require 'dotenv'
require 'base64'

module DeploymentMethod
  class GcloudRun < Base
    KUBECONFIGS_BASE_PATH = "config/kubernetes/"
    CERTS_BASE_PATH = "config/certs/"
    KUBE_TMP_PATH = "/home/tmp/"
    WWW_DEPLOYMENT_LABEL = "www"
    GCLOUD_PROJECT_ID = ENV["GOOGLE_CLOUD_PROJECT"]

    # gcloud run deploy helloworld   --image gcr.io/$GOOGLE_CLOUD_PROJECT/helloworld   --platform managed   --region us-central1   --allow-unauthenticated
    # gcloud builds submit --tag gcr.io/$GOOGLE_CLOUD_PROJECT/helloworld

    def initialize; end

    # verify can deploy

    def verify_can_deploy(options = {})
      super(options)
    end

    def initialization(options = {})
      super(options)
    end

    def gcloud_cmd(options = {})
      website, website_location = get_website_fields(options)
      project_path = website.repo_dir
      "timeout 300 sh -c \"cd #{project_path} && gcloud --project #{GCLOUD_PROJECT_ID} #{options[:subcommand]}\""
    end

    def image_tag_url(options = {})
      website, website_location = get_website_fields(options)

      tag_name = DeploymentMethod::Util::InstanceImageManager.tag_name(
        website: website,
        execution_id: runner.execution.id
      )

      "gcr.io/#{GCLOUD_PROJECT_ID}/#{website.site_name}:#{tag_name}"
    end

    def build_image(options = {})
      website, website_location = get_website_fields(options)

      image_url = image_tag_url(options)

      # build

      result = ex("gcloud_cmd", {
        website: website,
        website_location: website_location,
        subcommand: "builds submit --tag #{image_url} --gcs-log-dir=gs://builds_logs/",
        ensure_exit_code: 0
      })
      
      raise "Unable to complete successfully the image build" if result[:exit_code] != 0

      # retrieve the build ID, it looks like:
      # Created
      # [https://.../71a90edd-6cbb-4898-9abf-1a58319df67e]
      line_with_build = result[:stderr]
        .lines.find { |line| line.include?("Created [https://cloudbuild.googleapis.com/") }

      unless line_with_build.present?
        raise "No created build link available"
      end

      build_id = line_with_build[line_with_build.rindex("/")+1..line_with_build.rindex("]")-1]

      if build_id.blank? || build_id.size <= 10
        raise "Unable to retrieve the build ID"
      end

      # retrieve the logs build
      result = ex("gcloud_cmd", {
        website: website,
        website_location: website_location,
        subcommand: "builds log #{build_id}",
        ensure_exit_code: 0
      })

      puts "OKOK result -> #{result}"
      # gcloud builds log "d4792597-70fb-4ac1-b326-f0a5e2901a96"

      image_url
    end

    def launch(options = {})
      website, website_location = get_website_fields(options)

      #ex("gcloud_cmd", {
      #  website: website,
      #  website_location: website_location,
      #  subcommand: "auth activate-service-account --key-file=/home/martin/works/openode-api/config/service_accounts/openode-deploy.json"
      #})

      build_image(options)
    end

    def hooks
      [
        Kubernetes.hook_error,
        Kubernetes.hook_verify_can_deploy,
        Kubernetes.hook_logs,
        Kubernetes.hook_finalize,
        Kubernetes.hook_finalize_done,
        Kubernetes.hook_verify_instance_up,
        Kubernetes.hook_verify_instance_up_done
      ]
    end
  end
end
