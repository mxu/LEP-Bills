class Congress < ActiveRecord::Base
  has_many :bills, :order => 'name'
  has_many :unimportant_bills, :class_name => 'Bill', :conditions => 'importance = 1', :order => 'name'
  has_many :regular_bills, :class_name => 'Bill',:conditions => 'importance = 2', :order => 'name'
  has_many :important_bills, :class_name => 'Bill',:conditions => 'importance = 3', :order => 'name'
  has_many :amendments, :order => 'name'
  has_and_belongs_to_many :representatives, :order => 'last_name, first_name'
  has_and_belongs_to_many :committees, :order => 'name'
  has_and_belongs_to_many :subcommittees, :order => 'name'
  
  def fnumber
    number = read_attribute(:number)
    number = "0#{number}" if number < 100
    number
  end
end
