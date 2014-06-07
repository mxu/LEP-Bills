class Committee < ActiveRecord::Base
  has_and_belongs_to_many :bills, :uniq => true
  has_and_belongs_to_many :congresses, :uniq => true
  has_many :amendments, :as => :sponsor
end
