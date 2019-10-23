# frozen_string_literal: true

class History < ApplicationRecord
  serialize :obj, JSON
end
