
class NotificationsController < SuperAdmin::SuperAdminController
  before_action only: %i[update delete] do
    @notification = Notification.find_by! id: params['id']
  end

  api!
  def create
    json(Notification.create!(notification_params))
  end

  def update
    json(@notification.update!(update_notification_params) && @notification)
  end

  private

  def notification_params
    params.require(:notification)
          .permit(:type, :level, :content, :website_id)
  end

  def update_notification_params
    params.require(:notification).permit(:level, :content)
  end
end
