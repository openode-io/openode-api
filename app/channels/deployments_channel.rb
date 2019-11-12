class DeploymentsChannel < ApplicationCable::Channel
  def subscribed
    deployment_id = params['deployment_id']

    deployment = Deployment.find_by! id: deployment_id

    reject unless deployment.website.accessible_by?(current_user)

    Rails.logger.info('DeploymentChannel - subscribed channel for ' \
      "deployment id #{deployment_id}...")

    stream_for deployment
  end

  def unsubscribed; end
end
