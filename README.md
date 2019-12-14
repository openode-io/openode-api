# openode-api


[![Build status](https://travis-ci.org/openode-io/openode-api.svg?branch=master)](https://travis-ci.org/openode-io/openode-api)


opeNode API


Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization


* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

# Requirements:
 * Redis for jobs syncing + Action Cable

# Installation

 * Install rvm, https://rvm.io/
 * rvm install ##.##.## where ##.##.## is the ruby version, see Gemfile
 * apt-get install libmysqlclient-dev
 * bundle install
 * If you have build machine (docker.images_location in .\*.openode.yml),
    remove first \~/.docker/config.json

# Configuration
 * cp .test.env .production.env # adapt the environment settings
 * cp .test.openode.yml .production.openode.yml

# Creating and running a new instance (for development)
 * cp .test.env .development.env # ensure to NOT have file named .env
 * rails db:create
 * rails db:migrate
 * rails db:seed
 * 
 * rails s                                   # starts the main API
 * RAILS_ENV=development rails jobs:work     # to run background tasks

# Testing
 * rubocop
 * rails test