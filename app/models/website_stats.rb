
class WebsiteStats < History
  belongs_to :website, foreign_key: :ref_id
end
