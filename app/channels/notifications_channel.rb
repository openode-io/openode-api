class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    # puts 'subscribed??'
    # stream_from "some_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
