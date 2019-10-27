class WebsiteUtilizationLog < History
  belongs_to :website, foreign_key: :ref_id

  def self.log(website, data)
    WebsiteUtilizationLog.create(
      ref_id: website.id,
      obj: data
    )
  end
end
