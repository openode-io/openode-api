
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

    website_ids = params['website'] ? [params['website']] : user_website_ids

    all_notifications = where_notifications(
      types: types,
      website_ids: website_ids
    )

    notifications = all_notifications
                    .order(created_at: :desc)
                    .limit(params['limit'] || 10)

    json(
      notifications: notifications,
      nb_unviewed: unviewed_notifications(
        user: @user,
        notifications: all_notifications
      ).count
    )
  end

  private

  def where_notifications(opts = {})
    base_criteria_notifications = Notification.where(type: opts[:types])

    base_criteria_notifications
      .where(website_id: nil)
      .or(base_criteria_notifications.where(website_id: opts[:website_ids]))
  end

  def unviewed_notifications(opts = {})
    # how many are unviewed?
    viewed_notification_ids = ViewedNotification
                              .where(user: opts[:user])
                              .pluck(:notification_id)

    opts[:notifications].where.not(id: viewed_notification_ids)
  end
end
