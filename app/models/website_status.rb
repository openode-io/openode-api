class WebsiteStatus < History
  belongs_to :website, foreign_key: :ref_id

  def self.log(website, data)
    WebsiteStatus.create(
      ref_id: website.id,
      obj: data
    )
  end
end
