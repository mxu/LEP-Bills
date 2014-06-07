class Event < ActiveRecord::Base
  belongs_to :bill
  has_one :roll_call
end
