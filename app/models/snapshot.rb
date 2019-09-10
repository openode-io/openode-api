class Snapshot < ApplicationRecord
  belongs_to :user
  belongs_to :website

  validates_inclusion_of :status, :in => %w( pending transferring active deleted to_delete )

  def as_json(options = {})
    opts = { :methods => [:url] }

    super(options.merge(opts))
  end

  def url
    begin
      "https://#{ENV["SNAPSHOTS_HOSTNAME"]}" +
        "/snapshots/#{website.site_name}/#{website.id}.tar.gz"
    rescue => ex
      Rails.logger.error "Issue building snapshot url #{ex}"
      ""
    end
  end

end
