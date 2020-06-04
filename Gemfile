# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.7.1'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.0.3'

gem 'mysql2'

# Use Puma as the app server
gem 'puma'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'

# Use ActiveModel has_secure_password
gem 'bcrypt'

gem 'andand'
gem 'attr_encrypted'
gem 'bcrypt_pbkdf'
gem 'countries'
gem 'daemons'
gem 'delayed_job_active_record'
gem 'dotenv-rails'
gem 'droplet_kit'
gem 'ed25519'
gem 'http'
gem 'mailgun-ruby'
gem 'net-sftp'
gem 'net-ssh'
gem 'paypal-checkout-sdk'
gem 'public_suffix'
gem 'rack-cors'
gem 'rack-timeout'
gem 'redis'
gem 'safe_attributes'
gem 'solid_assert'
gem 'sshkey'
gem 'uptimerobot'
gem 'vultr'
gem 'will_paginate'

gem 'rubocop-rails'

gem 'apipie-rails'
gem 'rest-client'

# Use ActiveStorage variant
# gem 'mini_magick', '~> 4.8'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
# gem 'rack-cors'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'simplecov'
  gem 'webmock'
end

group :development do
  gem 'listen', '>= 3.0.5'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
