# frozen_string_literal: true

class Snapshot < ApplicationRecord
  belongs_to :user
  belongs_to :website

  STATUSES = %w[pending transferring active deleted to_delete].freeze
  validates :status, inclusion: { in: STATUSES }

  def as_json(options = {})
    opts = { methods: [:url] }

    super(options.merge(opts))
  end

  def url
    "https://#{ENV['SNAPSHOTS_HOSTNAME']}" \
      "/snapshots/#{website.site_name}/#{website.id}.tar.gz"
  rescue StandardError => e
    Rails.logger.error "Issue building snapshot url #{e}"
    ''
  end

  def change_status!(status)
    self.status = status
    save!
  end
end
