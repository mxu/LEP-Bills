class RollCall < ActiveRecord::Base
  belongs_to :event
  has_many :representatives, :through => :votes
  has_many :votes
end
