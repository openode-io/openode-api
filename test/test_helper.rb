ENV['RAILS_ENV'] = 'test'
require_relative '../config/environment'
require 'rails/test_help'

require 'simplecov'
SimpleCov.start

class ActiveSupport::TestCase

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  def prepare_ssh_session(cmd, output)
    story do |session|
      channel = session.opens_channel
      channel.sends_exec cmd
      channel.gets_data output
      channel.gets_close
      channel.sends_close
    end
  end

  def begin_ssh
    Remote::Ssh.set_conn_test(connection)
  end

  def default_user
    User.find_by email: "myadmin@thisisit.com"
  end

  def default_headers_auth
    {
      "x-auth-token": "1234s56789"
    }
  end

  # Add more helper methods to be used by all tests here...
end
