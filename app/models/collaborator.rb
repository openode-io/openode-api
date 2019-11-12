class Collaborator < ApplicationRecord
  belongs_to :website
  belongs_to :user
end
