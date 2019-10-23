# frozen_string_literal: true

class WebsiteEvent < History
  belongs_to :website, foreign_key: :ref_id
end
