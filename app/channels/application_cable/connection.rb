module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      token = request.headers['token'] || request.params['token']
      self.current_user = User.find_by token: token

      reject_unauthorized_connection unless current_user

      logger.add_tags current_user.email
    end

    def disconnect; end
  end
end
