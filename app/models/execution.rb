class Execution < ApplicationRecord
  serialize :result, JSON

  belongs_to :website
  belongs_to :website_location

  before_create :initialize_status

  STATUS_SUCCESS = "success"
  STATUS_FAILED = "failed"
  STATUS_RUNNING = "running"
  STATUSES = [STATUS_SUCCESS, STATUS_FAILED, STATUS_RUNNING]

  validates_inclusion_of :status, :in => STATUSES

  def failed!
  	self.status = STATUS_FAILED
  	self.save
  end

  def succeed!
  	self.status = STATUS_SUCCESS
  	self.save
  end

  def add_error!(ex)
  	result["errors"] ||= []

  	result["errors"] << {
		"title" => ex.message ? ex.message : "Global exception",
		"exception" => ex
	}

	self.save
  end

  def save_steps(results)
  	self.result["steps"] ||= []

  	self.result["steps"] = result["steps"] + 
	  	results.map do |current_result|
	  		Str::Encode.strip_invalid_chars(current_result)
	  	end

  	self.save
  end

  def initialize_status
  	self.status = STATUS_RUNNING
  	self.result ||= {}
  	self.result["steps"] = []
  	self.result["errors"] = []
  end

end
