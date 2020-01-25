
class UserNotificationsController < ApplicationController
  before_action :authorize

  api!
  # params: limit, types, website
  def index
    user_website_ids = @user.websites_with_access.pluck(:id)

    types = if params['types']
              params['types'].split(",")
            else
              %w[GlobalNotification WebsiteNotification]
      end

    base_criteria_notifications = Notification.where(type: types)

    all_notifications = base_criteria_notifications
                        .where(website_id: nil)
                        .or(base_criteria_notifications.where(website_id: user_website_ids))

    notifications = all_notifications
                    .order(created_at: :desc)
                    .limit(params['limit'] || 10)

    # how many are unviewed?
    viewed_notification_ids = ViewedNotification
                              .where(user: @user)
                              .pluck(:notification_id)
    unviewed_notifications = all_notifications.where.not(id: viewed_notification_ids)

    json(
      notifications: notifications,
      nb_unviewed: unviewed_notifications.count
    )
  end
end
