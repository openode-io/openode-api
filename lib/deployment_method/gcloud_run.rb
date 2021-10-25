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

    def build_image(options = {})
      website, website_location = get_website_fields(options)

      puts "GCLOUD_PROJECT_ID = #{GCLOUD_PROJECT_ID}"
    end

    def launch(options = {})
      website, website_location = get_website_fields(options)

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
