class Bill < ActiveRecord::Base
  has_and_belongs_to_many :sponsors, :join_table => "bills_sponsors", :class_name => "Representative", :uniq => true, :order => 'last_name, first_name'
  has_and_belongs_to_many :cosponsors, :join_table => "bills_cosponsors", :class_name => "Representative", :uniq => true, :order => 'last_name, first_name'
  
  has_many :events
  has_and_belongs_to_many :committees, :uniq => true, :order => 'name'
  has_and_belongs_to_many :subcommittees, :uniq => true, :order => 'name'
  has_many :amendments, :order => 'name'
  has_many :passed_amendments, :class_name => "Amendment", :conditions => 'passed = true', :order => 'name'
  belongs_to :congress
  
  # should be unused now
  def number_of_amendments_passed
    passed = 0
    self.amendments.each {|amendment| passed += 1 if amendment.passed }
    return passed
  end
  
  def multiple_referrals
    return 0 if self.committees.nil? or self.committees.size <= 1
    return 1
  end
  
end
