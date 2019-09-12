class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  ValidationError = Class.new(StandardError)

  def vault
    Vault.find_by ref_id: self.id
  end
end
