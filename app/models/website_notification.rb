
class WebsiteNotification < Notification
  belongs_to :website

  validates :website, presence: true
end
