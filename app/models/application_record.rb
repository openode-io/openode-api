class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  ValidationError = Class.new(StandardError)
end
