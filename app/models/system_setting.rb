class SystemSetting < ApplicationRecord
  serialize :content, JSON

  def self.global_msg
    SystemSetting.find_or_create_by name: "global_msg"
  end
end
