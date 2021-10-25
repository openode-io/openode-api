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

      result = ex("gcloud_cmd", {
        website: website,
        website_location: website_location,
        subcommand: "builds submit --tag #{image_url}"
      })
      puts "image_url built = #{image_url}"

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
