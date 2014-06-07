class Representative < ActiveRecord::Base
  has_and_belongs_to_many :sponsored_bills, :join_table => "bills_sponsors", :class_name => "Bill", :uniq => true, :order => 'name'
  has_and_belongs_to_many :cosponsored_bills, :join_table => "bills_cosponsors", :class_name => "Bill", :uniq => true, :order => 'name'
  has_many :roll_calls, :through => :votes
  has_many :votes
  has_many :amendments, :as => :sponsor
  has_and_belongs_to_many :congresses, :order => 'number'
  
  # return full name with state/district
  def name
    s = self.last_name
    s << ', ' + self.first_name unless self.first_name.nil?
    s << ' ' + self.middle_name unless self.middle_name.nil?
    s << ' ' + self.nickname unless self.nickname.nil?
    s << ', ' + self.suffix unless self.suffix.nil?
    s << " (#{self.state}-#{self.district})" unless self.state.nil? or self.district.nil?
    s << " (#{self.state}-AT LARGE)" unless self.state.nil? or !self.district.nil?
    s
  end
	
	def bills
		sponsored_bills + cosponsored_bills
	end
  
  def passed_bills
    self.sponsored_bills.reject { |b| b.passed == false or b.passed.nil? }
  end

  def failed_bills
    self.sponsored_bills.reject { |b| b.passed }
  end
  
  def passed_cosponsored_bills
    self.cosponsored_bills.reject { |b| b.passed == false or b.passed.nil? }
  end
  
  def failed_cosponsored_bills
    self.cosponsored_bills.reject { |b| b.passed }
  end
  
  def passed_amendments
    self.amendments.reject { |a| a.passed == false or a.passed.nil? }
  end

  def failed_amendments
    self.amendments.reject { |a| a.passed }
  end
    
  def num_cosponsored_passed
    passed = 0
    self.cosponsored_bills.each {|bill| passed += 1 if bill.passed }
    return passed
  end
  
  def num_bills_passed
    passed = 0
    self.sponsored_bills.each {|bill| passed += 1 if bill.passed }
    return passed
  end
  
  # TODO case of 'Brown (OH)' or 'Jackson-Lee (TX)' or 'McCandless, Alfred A. (Al)'
  def self.locate(name)
    name.sub!(/"(\w+)"/, "(#{$1})")
    last, rest, suffix = name.sub(/^Rep /, '').split(', ')
    rest, nickname = rest.gsub(/ \((\w+)\)/, ''), $1
    first, middle = rest.split
    
    if r = Representative.find_by_last_name_and_first_name(last, first)
      return r
    else
      r = Representative.find_or_create_by_last_name_and_first_name(last, first)
      r.middle_name = middle
      r.nickname = nickname
      r.suffix = suffix
      r.save
      return r
    end
  end
  
#Rep Cunningham, Randy (Duke)  
#Rep Cramer, Robert E. (Bud), Jr.
#Rep Lipinski, William O.
#Rep Istook, Ernest J., Jr.
#Rep McKeon, Howard P. "Buck"
#Rep Miller, Dan
#Rep Nethercutt, George R., Jr.
#Rep Myrick, Sue Wilkins
  
end
