# snapshot.rb

require 'bcrypt'

class Snapshot < ApplicationRecord
  serialize :steps, JSON

  belongs_to :website

  # after X hours the snapshot is expired and no more available
  DEFAULT_EXPIRATION_HOURS = 1
  DEFAULT_DESTINATION_ROOT_PATH = '/snapshots/'
  DEFAULT_HOSTNAME = "snapshots.openode.io"
  DEFAULT_SNAPSHOT_EXTENSION = ".zip"

  LIMIT_LATEST_MINUTES = 10

  STATUS_PENDING = 'pending'
  STATUS_IN_PROGRESS = 'in_progress'
  STATUS_SUCCEED = 'succeed'
  STATUS_FAILED = 'failed'

  DEFAULT_STATUS = STATUS_PENDING

  STATUSES = [DEFAULT_STATUS, STATUS_IN_PROGRESS, STATUS_SUCCEED, STATUS_FAILED].freeze

  before_validation :prepare_new_snapshot, on: :create

  validates :status, inclusion: { in: STATUSES }
  validates :path, presence: true, format: {
    with: %r{\A(\w|-|/)+\z}i, message: "ensure to have a valid path format"
  }

  validate :fail_on_latest_user_reaching_limit, on: :create

  def fail_on_latest_user_reaching_limit
    latest_user_snapshot = Snapshot.where(website: website.user.websites_with_access).last

    return unless latest_user_snapshot

    if (Time.zone.now - latest_user_snapshot.created_at) / 60.0 < LIMIT_LATEST_MINUTES
      errors.add(:user,
                 "limit reached (1 per #{LIMIT_LATEST_MINUTES} minutes).")
    end
  end

  def get_url
    "https://#{DEFAULT_HOSTNAME}#{destination_path}"
  end

  def prepare_new_snapshot
    self.status = DEFAULT_STATUS
    self.expire_at = Time.zone.now + DEFAULT_EXPIRATION_HOURS.hours
    self.uid = SecureRandom.hex(32)
    self.destination_path = get_destination_path(DEFAULT_SNAPSHOT_EXTENSION)
    self.url = get_url
    self.steps = []
  end

  def get_destination_folder
    "#{DEFAULT_DESTINATION_ROOT_PATH}#{uid}/"
  end

  def get_destination_path(extension)
    "#{get_destination_folder.delete_suffix('/')}#{extension}"
  end
end
