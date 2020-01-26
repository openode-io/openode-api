
class UserNotificationsController < ApplicationController
  before_action :authorize

  api!
  # params: limit, types, website
  def index
    types = params['types'] ? params['types'].split(",") : nil

    all_notifications = Notification.of_user(@user,
                                             types: types,
                                             website: params['website'])

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

  def mark_viewed
    user_notifications = Notification.of_user(@user)
    all_unviewed_notifications = unviewed_notifications(
      notifications: user_notifications,
      user: @user
    )

    notifications = if params['all']
                      all_unviewed_notifications
                    else
                      all_unviewed_notifications.where(id: params['notifications'])
    end

    marked = []

    notifications.each do |notification|
      next if notification.viewed_by?(@user)

      ViewedNotification.create(
        notification: notification,
        user: @user
      )

      marked << notification
    end

    json(
      nb_marked: marked.length,
      marked: marked
    )
  end

  private

  def unviewed_notifications(opts = {})
    opts[:notifications].where(
      "notifications.id NOT IN(" \
      " SELECT notification_id "\
      " FROM viewed_notifications vn " \
      " WHERE vn.user_id = ? " \
      ")", opts[:user].id
    )
  end
end
