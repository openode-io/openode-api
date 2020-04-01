class WebsiteStatus < History
  belongs_to :website, foreign_key: :ref_id

  def self.log(website, data)
    st = website.statuses.first

    if st
      st.obj = data
      st.save

      st
    else
      WebsiteStatus.create!(
        ref_id: website.id,
        obj: data
      )
    end
  end
end
