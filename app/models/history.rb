class History < ApplicationRecord
  serialize :obj, JSON
end
