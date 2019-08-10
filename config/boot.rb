ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
require 'bootsnap/setup' # Speed up boot time by caching expensive operations.

# Verify database connection:
if defined? Rails
  require './config/environment.rb'
  ActiveRecord::Base.establish_connection # Establishes connection
  ActiveRecord::Base.connection # Calls connection object
end
