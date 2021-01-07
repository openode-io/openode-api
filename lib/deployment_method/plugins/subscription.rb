module DeploymentMethod
  module Plugins
    module Subscription
      def subscription_init(options = {})
        website = options[:website]
        user = website.user

        # if any, use subscription
        ::Subscription.start_using_subscription(user, website) if website.auto_plan?
      end

      def subscription_stop(options = {})
        website = options[:website]
        ::Subscription.stop_using_subscription(website) if website.auto_plan?
      end
    end
  end
end
