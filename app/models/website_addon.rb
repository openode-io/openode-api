class WebsiteAddon < ApplicationRecord
  include WithPlan

  serialize :obj, JSON

  belongs_to :website
  belongs_to :addon

  delegate :user, to: :website

  before_validation :init_default_values
  before_validation :downcase_name
  before_validation :enforce_image_tag

  validates :name, presence: true
  validates :website, presence: true
  validates :addon, presence: true

  validate :validate_account_type
  validate :validate_disallow_open_source
  validate :validate_addon_obj_fields, on: :update
  validate :validate_storage_gb, on: :update

  validates_format_of :name, with: /[a-z]+-?([a-z0-9])+/i
  STATUS_ONLINE = "online"
  STATUS_OFFLINE = "offline"
  STATUSES = [STATUS_ONLINE, STATUS_OFFLINE, ""]

  validates :status, inclusion: { in: STATUSES }

  def downcase_name
    self.name = name.downcase
  end

  def init_default_values
    self.obj ||= {}

    if addon&.obj
      self.obj['exposed_port'] ||= addon.obj['target_port']
      self.obj['persistent_path'] ||= addon.obj['persistent_path']
    end

    self.obj['tag'] ||= "latest"

    self.obj['env'] ||= {}

    self.name ||= addon.name
    self.storage_gb ||= 1

    unless account_type
      min_plan = WithPlan.find_min_plan(addon.obj['minimum_memory_mb'])
      self.account_type = min_plan&.dig(:internal_id)
    end

    default_env_variables
  end

  def enforce_image_tag
    self.obj["tag"] = Io::Cmd.sanitize_input_cmd(obj["tag"])
  end

  def tag
    obj["tag"] || "latest"
  end

  def image_tag
    "#{addon.obj['image']}:#{tag}"
  end

  def persistence?
    addon&.requires_persistence?
  end

  def online?
    status == STATUS_ONLINE
  end

  def default_env_variables
    (addon.obj&.dig("required_env_variables") || []).each do |required_env_variable|
      self.obj['env'][required_env_variable] ||=
        addon.obj.dig('env_variables', required_env_variable)
    end
  end

  def as_json(options = {})
    options[:methods] = [:addon]
    super
  end

  def validate_disallow_open_source
    if account_type == Website::OPEN_SOURCE_ACCOUNT_TYPE ||
       website.account_type == Website::OPEN_SOURCE_ACCOUNT_TYPE
      errors.add(:account_type, "open source not allowed")
    end
  end

  def validate_addon_obj_fields
    %w[
      minimum_memory_mb
      required_env_variables
      required_fields
    ].each do |field_name|
      if addon.obj_field?(field_name)
        send("validate_#{field_name}", field_name, addon.obj&.dig(field_name))
      end
    end
  end

  def validate_storage_gb
    return unless persistence?

    unless storage_gb.positive? && storage_gb <= 10
      errors.add(:storage_gb, "should be between 1 and 10")
    end
  end

  def validate_minimum_memory_mb(_field_name, min_ram)
    if plan[:ram] < min_ram
      errors.add(:minimum_memory_mb, "should be larger or equal than #{min_ram} MB")
    end
  end

  def validate_required_env_variables(_field_name, required_env_variables)
    return errors.add(:env, 'required') unless obj&.dig('env')

    required_env_variables.each do |required_env_variable|
      unless obj&.dig('env', required_env_variable)
        errors.add(:env, "variable #{required_env_variable} missing")
      end
    end
  end

  def validate_required_fields(_field_name, required_fields)
    required_fields.each do |required_field|
      errors.add(required_field, "can't be blank") if self.obj[required_field].blank?
    end
  end
end
