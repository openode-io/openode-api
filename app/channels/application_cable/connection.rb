module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      # puts 'hello connect?'
      self.current_user = 123_456 # find_verified_user
      # logger.add_tags current_user.name
    end

    def disconnect
      # puts 'disconnected.'
    end
  end
end
