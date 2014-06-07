class AdminController < ApplicationController
  layout 'default'
	def index
		list
		render :action => 'list'
	end

	# GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
	verify :method => :post, :only => [ :delete_all ],
				 :redirect_to => { :action => :list }

	def list
		@bill_pages, @bills = paginate :bills, :per_page => 25, :conditions => { :congress_id => 2 }, :order => :name
	end

	def show
		@bill = Bill.find(params[:id])
	end

	# clear data from all tables
	def delete_all
	  Bill.delete_all
	  Cosponsorship.delete_all
	  Representative.delete_all
	  Event.delete_all
	  RollCall.delete_all
	  redirect_to :action => "index"
	end
	
	def clean_committees
	 if committee = Committee.find_by_name("Transportation") then
	   new_committee = Committee.find_by_name("Transportation and Infrastructure")
	   committee.bills.each do |bill|
	     bill.committees.delete(committee)
	     bill.committees << new_committee unless bill.committees.include?(new_committee)
	     bill.save
     end
     Committee.delete(committee.id) if committee.bills.size == 0
   end
   
   if committee = Committee.find_by_name("Oversight") then
	   new_committee = Committee.find_by_name("House Oversight")
	   committee.bills.each do |bill|
	     bill.committees.delete(committee)
	     bill.committees << new_committee unless bill.committees.include?(new_committee)
	     bill.save
     end
     Committee.delete(committee.id) if committee.bills.size == 0
   end
   
   if committee = Committee.find_by_name("Government Reform") then
	   new_committee = Committee.find_by_name("Government Reform and Oversight")
	   committee.bills.each do |bill|
	     bill.committees.delete(committee)
	     bill.committees << new_committee unless bill.committees.include?(new_committee)
	     bill.save
     end
     Committee.delete(committee.id) if committee.bills.size == 0
   end
   
   redirect_to :action => "index"
	end
	
	def fetch
    num_fetched = fetch_bills(1, 100, 105) # 4874 in 105, 5681 in 106
		
		flash[:notice] = "Successfully fetched " + num_fetched.to_s + " records."
		redirect_to :action => "list"
	end
	
	def fetch_rc
    fetch_roll_calls
		
		redirect_to :action => "list"
	end

  def show_rep
    rep = Representative.find(params[:id])
    render :partial => "show_rep", :locals => { :rep => rep }
    #return if request.xhr?
  end
  
  def show_roll_call
    roll_call = RollCall.find(params[:id])
    yeas = Vote.find(:all, :conditions => { :roll_call_id => roll_call, :vote => 'Aye' })
    nays = Vote.find(:all, :conditions => { :roll_call_id => roll_call, :vote => 'No' })
    notvotings = Vote.find(:all, :conditions => { :roll_call_id => roll_call, :vote => 'Not Voting' })    
    render :partial => "show_roll_call", :locals => { :roll_call => roll_call, :yeas => yeas, :nays => nays, :notvotings => notvotings }
  end
  
  def congresses
    congresses = Congress.find(:all)
    representatives = Representative.find(:all)
    committees = Committee.find(:all)
    subcommittees = Subcommittee.find(:all)
    congresses.each do |congress|
      congress.representatives.clear
      representatives.each {|rep| congress.representatives << rep if rep.bills.any? {|bill| bill.congress == congress } or rep.cosponsored_bills.any? {|bill| bill.congress == congress } }
      congress.committees.clear
      committees.each {|committee| congress.committees << committee if committee.bills.any? {|bill| bill.congress == congress } }
      congress.subcommittees.clear
      subcommittees.each {|subcommittee| congress.subcommittees << subcommittee if subcommittee.bills.any? {|bill| bill.congress == congress } }      
      congress.save
    end
    
    redirect_to :action => "index"
  end
  
  # parse the events of a given bill
  def parse_bill
    bill = Bill.find(params[:id])
    parse_events(bill.events)
    redirect_to :action => "show", :id => bill
  end
  
  # parse the events for all bills
  def parse_all_bills
    bills = Bill.find(:all)
    bills.each do |bill|
      parse_events(bill.events)
    end
    redirect_to :action => "index"
  end
  
  def parse_amendments
    events = Event.find(:all, :conditions => "title LIKE '%H\.AMDT\.%'")
    amendments = []
    events.each do |event|
      amendment_number = event.title.scan(/H\.AMDT\.(\d+)/).first.first
      amendments << [amendment_number, event.bill.congress.number] unless amendments.include?([amendment_number, event.bill.congress.number])
    end
    amendments.each do |amendment|
      fetch_amendment(amendment[0], amendment[1])
    end
    redirect_to :action => "index"
  end
  


  #e = Event.find(:all, :conditions => "title LIKE '%sequentially%'")
  private
  def parse_events(events)
    events.each do |event|
      if event.title.sub(/ \(.+\)/, '') =~ /Referred to House ([\w\s']+)/ or event.title.sub(/ \(.+\)/, '') =~ /Referred to the House Committee on (?:the )?([\w\s']+)\./ or event.title =~ /Referred sequentially to the House Committee on (?:the )?([\w\s']+) for/ or event.title =~ /The House Committee on (Appropriations) reported an original measure/ then
        committee = Committee.find_or_create_by_name($1.chomp(' '))
        event.bill.committees << committee unless event.bill.committees.include?(committee)
      end
      if event.title.sub(/ \(.+\)/, '') =~ /Referred to the Subcommittee on (?:the )?(.+?)( for.+)?[\.,]/ then
        subcommittee = Subcommittee.find_or_create_by_name($1.chomp(' '))
        event.bill.subcommittees << subcommittee unless event.bill.subcommittees.include?(subcommittee)
      end
      if event.title =~ /The House Committee on Appropriations reported an original measure/ then
        event.bill.introduced_on = event.date if event.bill.introduced_on.nil?
        event.bill.referred_to_committee_on = event.date if event.bill.referred_to_committee_on.nil?
        event.bill.reported_by_committee_on = event.date if event.bill.reported_by_committee_on.nil?        
      end
      event.bill.forwarded_from_subcommittee_to_committee_on = event.date if event.title =~ /Forwarded by Subcommittee to Full Committee/ and event.bill.forwarded_from_subcommittee_to_committee_on.nil?
      event.bill.reported_by_committee_on = event.date if event.title =~ /Reported \(Amended\) by the Committee/ or event.title =~ /Reported by the Committee/ and event.bill.reported_by_committee_on.nil?
      event.bill.sent_to_conference_committee_on = event.date if event.title =~ /The Speaker appointed conferees/ and event.bill.sent_to_conference_committee_on.nil?
      event.bill.conference_committee_report_issued_on = event.date if event.title =~ /Conference report H. Rept. \d+-\d+ filed/ and event.bill.conference_committee_report_issued_on.nil?
      event.bill.conference_committee_passed_house_on = event.date if event.title =~ /On agreeing to the conference report Agreed/ and event.bill.conference_committee_passed_house_on.nil?
      event.bill.conference_committee_passed_senate_on = event.date if event.title =~ /Senate agreed to conference report/ and event.bill.conference_committee_passed_senate_on.nil?
      event.bill.rule_reported_on = event.date if event.title =~ /Rules Committee Resolution H. Res. \d+ Reported to House/ and event.bill.rule_reported_on.nil?
      event.bill.rule_passed_on = event.date if event.title =~ /Rule H. Res. \d+ passed House/ and event.bill.rule_passed_on.nil?
      event.bill.rules_suspended_on = event.date if event.title =~ /Considered under suspension of the rules/ and event.bill.rules_suspended_on.nil?
      event.bill.considered_by_unanimous_consent_on = event.date if event.title =~ /Considered by unanimous consent/ and event.bill.considered_by_unanimous_consent_on.nil?
      event.bill.placed_on_union_calendar_on = event.date if event.title =~ /Placed on the Union Calendar/ and event.bill.placed_on_union_calendar_on.nil?
      event.bill.placed_on_house_calendar_on = event.date if event.title =~ /Placed on the House Calendar/ and event.bill.placed_on_house_calendar_on.nil?
      event.bill.placed_on_private_calendar_on = event.date if event.title =~ /Placed on the Private Calendar/ and event.bill.placed_on_private_calendar_on.nil?
      event.bill.placed_on_corrections_calendar_on = event.date if event.title =~ /Placed on the Corrections Calendar/ and event.bill.placed_on_corrections_calendar_on.nil?
      event.bill.placed_on_discharge_calendar_on = event.date if event.title =~ /Placed on the Discharge Calendar/ and event.bill.placed_on_discharge_calendar_on.nil?
      event.bill.passed_house_on = event.date if event.title =~ /On passage Passed/ or event.title =~ /On motion to suspend the rules and pass the bill(, as amended)? Agreed/ or event.title =~ /On motion that the House suspend the rules and agree to the Senate amendments? Agreed/ or event.title =~ /Passed House (\(Amended\))? by/ and event.bill.passed_house_on.nil?
      event.bill.failed_house_on = event.date if event.title =~ /On passage Failed/ or event.title =~ /On motion to suspend the rules and pass the bill(, as amended)? Failed/ or event.title =~ /On motion that the House suspend the rules and agree to the Senate amendments? Failed/ and event.bill.failed_house_on.nil?
      event.bill.passed_senate_on = event.date if event.title =~ /Passed Senate/ or event.title =~ /Received in the Senate, read twice, considered, read the third time, and passed/ and event.bill.passed_senate_on.nil?
      event.bill.received_in_senate_on = event.date if event.title =~ /Received in the Senate/ and event.bill.received_in_senate_on.nil?
      event.bill.referred_to_committee_on = event.date if event.title =~ /Referred to the Committee/ and event.bill.referred_to_committee_on.nil?
      event.bill.referred_to_committee_on = event.date if event.title =~ /Referred( sequentially)? to the House Committee/ and event.bill.referred_to_committee_on.nil?
      event.bill.referred_to_subcommittee_on = event.date if event.title =~ /Referred to the Subcommittee/ and event.bill.referred_to_subcommittee_on.nil?
      event.bill.committee_hearing_held_on = event.date if event.title == "Committee Hearings Held." or event.title =~ /Field Hearings Held/ and event.bill.committee_hearing_held_on.nil?
      event.bill.subcommittee_hearing_held_on = event.date if event.title == "Subcommittee Hearings Held." and event.bill.subcommittee_hearing_held_on.nil?
      event.bill.committee_markup_held_on = event.date if event.title == "Committee Consideration and Mark-up Session Held." and event.bill.committee_markup_held_on.nil?
      event.bill.subcommittee_markup_held_on = event.date if event.title == "Subcommittee Consideration and Mark-up Session Held." and event.bill.subcommittee_markup_held_on.nil?
      event.bill.presented_to_president_on = event.date if event.title =~ /Presented to President/
      event.bill.vetoed_by_president_on = event.date if event.title =~ /Vetoed by President/
      event.bill.signed_by_president_on = event.date if event.title =~ /Signed by President/
      event.bill.house_veto_override_failed_on = event.date if event.title =~ /On passage, the objections of the President to the contrary notwithstanding Failed/ and event.bill.house_veto_override_failed_on.nil?
      event.bill.house_veto_override_on = event.date if event.title =~ /Two-thirds of the Members present having voted in the affirmative the bill is passed/ or event.title=~ /Passed House Over Veto/ and event.bill.house_veto_override_on.nil?      
      event.bill.save
    end
  end
  
  public
  def fetch_amendment(amendment_number, congress)
    this_congress = Congress.find_or_create_by_number(congress)
    url = URI.parse("http://thomas.loc.gov/cgi-bin/bdquery/z?d#{congress}:HZ#{amendment_number}:") # first we parse the URL
    response = Net::HTTP.get_response(url) # then we fetch the page
    array = response.body.to_a # here we store in an array each line of the body of the page
    name = array[29].scan(/H\.AMDT\.(\d+)/).first.first
    amendment = Amendment.find_or_create_by_name_and_congress_id(name, this_congress.id)
    amendment.congress = this_congress
    amendment.bill = Bill.find_by_name_and_congress_id(response.body.scan(/<br>Amends: <a href=.+>H\.R\.(\d+)<\/a>/).flatten.to_s, this_congress.id)
    amendment.offered_on = response.body.scan(/offered (\d+\/\d+\/\d+)/).to_s
    amendment.description = response.body.scan(/<p>AMENDMENT DESCRIPTION:<br>(.+)\n<p>/).flatten.to_s
    amendment.purpose = response.body.scan(/<p>AMENDMENT PURPOSE:<br>(.+)\n<p>/).flatten.to_s
    amendment.passed = false
    amendment.passed = true if response.body =~ /On agreeing to .+ Agreed to/
    name = response.body.scan(/<br>Sponsor: <a href=.+>(.+)<\/a>/).flatten.to_s
    if name =~ /Rep/ then
      amendment.sponsor = Representative.locate(name)
    elsif
      amendment.sponsor = Committee.find_by_name(name.sub(/House /, ""))
    end
    amendment.save
  end
	
	private
	def fetch_bills(bill_start,	bill_end, congress)		

    this_congress = Congress.find_or_create_by_number(congress)
		# iterate through each bill
		bill_start.upto(bill_end) do |bill_number|
			url = URI.parse("http://thomas.loc.gov/cgi-bin/bdquery/D?d#{congress}:#{bill_number}:./list/bss/d#{congress}HR.lst:@@@S") # first we parse the URL
			response = Net::HTTP.get_response(url) # then we fetch the page
			array = response.body.to_a # here we store in an array each line of the body of the page
			name = array[31].scan(/H\.R\.(\d+)/).first.first
			bill = Bill.find_or_create_by_name_and_congress_id(name, this_congress.id)
			bill.congress = this_congress
			bill.title = array[32][18..-1].chomp
			bill.introduced_on = array[35].scan(/(\d+\/\d+\/\d+)/).to_s  # line 35 contains '(introduced 2/11/1999)', pull out date
			sponsor_data = array[34].scan(/>Rep (.+)<\/a> \[(..)-?(\d{0,2})\]\n/)
			sponsor = Representative.locate(sponsor_data.first[0])
			if sponsor.state.nil? or sponsor.district.nil? then
			  sponsor.state = sponsor_data.first[1]
			  sponsor.district = sponsor_data.first[2]
			  bill.sponsors += [sponsor]
				#bill.sponsors.save
			end
			
			# events
			events = [] # array to hold the events associated with a bill
			response.body.scan(/<strong>(.+):<\/strong><dd>([[:print:]\n]+?)(<dt>|<\/dl>|<dl>)/) {|x,y| events << [x,y] } # here we scan the page for events, putting the date and event into an array
      Event.delete_all "bill_id = #{bill.id}"
      events.each do |x|
        event = Event.new     
        
        rc = x[1].scan(/\(<a href="\D+(\d+).+">Roll no. (\d+)<\/a>\)/)
        if rc.size > 0 then
          year, num = rc.first
          roll = RollCall.find_or_create_by_roll_number(num)
          num.insert(0, '0') until num.size == 3
          roll.year = year
          roll.save
          event.roll_call = roll
        end
           
        event.date = x[0]
        event.title = x[1].gsub(/<\/?[^>]*>/, "").gsub(/\n/, "")  # remove html tags and newlines
        bill.passed = true if event.title == "Signed by President."
        bill.events << event
        event.save
      end

			# TODO cosponsors include those that have withdrawn
			# cosponsors
			if array[36].include?('href')
				url.query[-1] = 'P'
				response = Net::HTTP.get_response(url) # fetch cosponsor page
				reps = Array.new # to store our array of reps cosponsoring
				s = response.body.scan(/>Rep (.+)<\/a> \[(..)-?(\d{0,2})\]\n/)
				s.shift # remove the first cosponsor, which is actually the sponsor
				s.each do |r|
					rep = Representative.locate(r[0])
					if rep.state.nil? or rep.district.nil? then
					  rep.state = r[1]
					  rep.district = r[2]
					  rep.save
					end
					# TTODO clean this up
					unless Cosponsorship.find(:first, :conditions => "bill_id = #{bill.id} AND representative_id = #{rep.id}")
						c = Cosponsorship.new
						c.bill_id = bill.id
						c.representative_id = rep.id
						c.date = r[3]
						c.save
					end
				end
			end		    
      
      bill.save
		end
		bill_end - bill_start + 1 # returns number of bills fetched
  end

  private
  def fetch_roll_calls
    roll_calls = RollCall.find(:all)
    roll_calls.each do |rc|
      roll_call_url = URI.parse("http://clerk.house.gov/evs/#{rc.year}/roll#{rc.roll_number}.xml")
      roll_call_body = Net::HTTP.get_response(roll_call_url).body
      rc.vote_question = roll_call_body.scan(/<vote-question>(.+)<\/vote-question/).to_s

      votes = roll_call_body.scan(/<recorded-vote><legislator party="\w" state="\w\w" role="legislator">(.+)<\/legislator><vote>(.+)<\/vote><\/recorded-vote>/)
      Vote.delete_all "roll_call_id = #{rc.id}"
      votes.each do |v|
        vote = Vote.new
        vote.vote = v[1]
        vote.representative = Representative.locate(v[0])
        vote.roll_call = rc
        vote.save
      end
    end
  end

end