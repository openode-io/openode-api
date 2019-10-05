class Deployment < ApplicationRecord
  serialize :result, JSON

  belongs_to :website
  belongs_to :website_location

  before_create :initialize_status

  STATUS_SUCCESS = "success"
  STATUS_FAILED = "failed"
  STATUS_RUNNING = "running"
  STATUSES = [STATUS_SUCCESS, STATUS_FAILED, STATUS_RUNNING]

  validates_inclusion_of :status, :in => STATUSES

  def initialize_status
  	self.status = STATUS_RUNNING
  	self.result ||= {}
  	self.result["steps"] = []
  end

end
