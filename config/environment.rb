# frozen_string_literal: true

# Load the Rails application.
require_relative 'application'

# Initialize the Rails application.
Rails.application.initialize!

puts "in env.rb"
CloudProvider::Manager.instance
