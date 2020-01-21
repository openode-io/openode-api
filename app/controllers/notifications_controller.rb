
class NotificationsController < SuperAdmin::SuperAdminController
  api!
  def create
    json(Notification.create!(notification_params))
  end

  private

  def notification_params
    params.require(:notification)
          .permit(:type, :level, :content, :website_id)
  end
end
