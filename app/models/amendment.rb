class Amendment < ActiveRecord::Base
  belongs_to :sponsor, :polymorphic => true
  belongs_to :bill
  belongs_to :congress
end
