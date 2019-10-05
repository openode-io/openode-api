class Deployment < ApplicationRecord
  serialize :result, JSON

  belongs_to :website
  belongs_to :website_location

  STATUS_SUCCESS = "success"
  STATUS_FAILED = "failed"
  STATUS_RUNNING = "running"
  STATUSES = [STATUS_SUCCESS, STATUS_FAILED, STATUS_RUNNING]

  validates_inclusion_of :status, :in => STATUSES

end
