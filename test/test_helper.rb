ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  def default_user
    User.find_by email: "myadmin@thisisit.com"
  end

  def default_headers_auth
    {
      "x-auth-token": "123456789"
    }
  end

  # Add more helper methods to be used by all tests here...
end
