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

# Configuration
 * cp .test.env .production.env # adapt the environment settings
 * cp .test.openode.yml .production.openode.yml