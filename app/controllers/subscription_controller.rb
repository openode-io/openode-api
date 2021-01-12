
class SubscriptionController < ApplicationController
  before_action do
    authorize
  end

  before_action do
    if params[:subscription_id]
      @subscription = @user.subscriptions.find(params[:subscription_id])
    end
  end

  def index
    json(@user.subscriptions.order(id: :desc))
  end

  def cancel
    paypal_api = Api::Paypal.new
    paypal_api.refresh_access_token

    paypal_api.execute(:post,
                       "/v1/billing/subscriptions/#{@subscription.subscription_id}/cancel",
                       '{"reason": "N/A"}')

    json({})
  end
end
