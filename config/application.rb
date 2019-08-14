require_relative 'boot'

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
# require "sprockets/railtie"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module OpenodeApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
  end
end

# do we have all env vars ?

if ENV["RAILS_ENV"] == "test"
  require 'dotenv'
  puts "loading test env"
  Dotenv.load('.test.env')
end

required_env_vars = [
  "SQL_HOST",
  "SQL_USER",
  "SQL_PASSWORD",
  "SQL_DATABASE",
  "AUTH_SALT",
  "VULTR_API_KEY",
  "RAILS_LOG_TO_STDOUT"
]

required_env_vars.each do |var|
  unless ENV[var]
    raise "missing env var #{var}"
  end
end

puts "Env: #{ENV["RAILS_ENV"]}"

# Relational db connection verification

puts "Verifying database connection..."
require "./config/environment.rb"
ActiveRecord::Base.establish_connection # Establishes connection
ActiveRecord::Base.connection # Calls connection object
puts "database connection valid"
