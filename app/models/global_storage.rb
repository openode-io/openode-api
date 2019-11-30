class GlobalStorage < ApplicationRecord
  serialize :obj, JSON
end
