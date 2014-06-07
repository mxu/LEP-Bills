class Vote < ActiveRecord::Base
  belongs_to :roll_call
  belongs_to :representative
end
