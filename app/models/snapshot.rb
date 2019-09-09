class Snapshot < ApplicationRecord
  belongs_to :user
  belongs_to :website

  validates_inclusion_of :status, :in => %w( pending transferring active deleted to_delete )

end
