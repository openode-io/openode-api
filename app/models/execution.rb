class Execution < ApplicationRecord
  serialize :result, JSON
  serialize :events, JSON
  serialize :obj, JSON

  STATUS_SUCCESS = 'success'
  STATUS_FAILED = 'failed'
  STATUS_RUNNING = 'running'
  STATUSES = [STATUS_SUCCESS, STATUS_FAILED, STATUS_RUNNING].freeze

  belongs_to :website, optional: true
  belongs_to :website_location, optional: true

  belongs_to :parent_execution,
             class_name: :Execution,
             optional: true

  before_create :initialize_status

  scope :by_user, lambda { |user|
    where(website_id: user.websites)
  }

  scope :running, lambda {
    where(status: STATUS_RUNNING)
  }

  scope :completed, lambda {
    where.not(status: STATUS_RUNNING)
  }

  scope :success, lambda {
    where(status: STATUS_SUCCESS)
  }

  scope :not_types, lambda { |specified_types|
    where.not(type: specified_types)
  }

  validates :status, inclusion: { in: STATUSES }

  def failed!
    self.status = STATUS_FAILED
    save
  end

  def succeed!
    self.status = STATUS_SUCCESS
    save
  end

  def add_error!(exception)
    result['errors'] ||= []

    result['errors'] << {
      'title' => exception.message || 'Global exception',
      'exception' => exception
    }

    save
  end

  def save_steps(results)
    result['steps'] ||= []

    result['steps'] = result['steps'] +
                      results.map do |current_result|
                        Str::Encode.strip_invalid_chars(current_result)
                      end

    save
  end

  def save_extra_attrib!(attrib_name, value)
    self.obj ||= {}
    self.obj[attrib_name] = value
    save
  end

  def initialize_status
    self.status = STATUS_RUNNING
    self.result ||= {}
    self.result['steps'] = []
    self.result['errors'] = []
  end
end
