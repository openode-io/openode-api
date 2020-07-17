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

  def simplified_container_statuses
    statuses = obj&.dig('containerStatuses')
    return [] unless statuses

    statuses.each do |s|
      s.delete("containerID")
      s.delete("image")
      s.delete("imageID")
    end

    statuses
  end

  def statuses_containing_terminated_reason(reason)
    simplified_container_statuses
      .select do |status|
        status.dig('lastState', 'terminated', 'reason').to_s.downcase == reason.downcase
      end
  end
end
