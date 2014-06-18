# This class contains all of the logic for getting information from Thomas and
# storing it in the database.

class CongressController < ApplicationController
  layout 'default'

  def index
    list
    render :action => "list"
  end

  def list
    @congresses = Congress.find(:all, :order => :number)
  end
  
  # Gets the bills from multiple congresses (chosen in the form) and also ranks,
  # parses, and links them.
  def fetch_multiple
	  start = Time.now
    first = params[:first].to_i
    last = params[:last].to_i
    params[:congress].to_i.upto(params[:congress_end].to_i) do |c|
      congress = Congress.find_or_create_by_number(c)
      first.upto(last) { |bill_number| fetch_bill(congress, bill_number) }
      roll_commands(congress)
    end
    flash[:notice] = "#{last-first+1} bills from each of the #{params[:congress].to_i.ordinalize}-#{params[:congress].to_i.ordinalize} were fetched and processed. Started "+start.to_s+"; finished "+Time.now.to_s
    puts "#{last-first+1} bills from each of the #{params[:congress].to_i.ordinalize}-#{params[:congress].to_i.ordinalize} were fetched and processed. Started "+start.to_s+"; finished "+Time.now.to_s
    redirect_to :action=>'index'
  end
  
  # Gets the bills from a single congress from Thomas
  def fetch
	  start = Time.now
    first = params[:first].to_i
    last = params[:last].to_i
    congress = Congress.find_or_create_by_number(params[:congress].to_i)
    first.upto(last) { |bill_number| fetch_bill(congress, bill_number) }
    flash[:notice] = "#{last-first+1} bills from the #{congress.number.ordinalize} were fetched. Started "+start.to_s+"; finished "+Time.now.to_s
    redirect_to :action => "index"
  end
  
  private
  
  # Runs all of the basic commands for a congress, for convenience
  def roll_commands(congress)
    fetch_amendments_for(congress)
    rank_congress(congress)
    congress.bills.each { |bill| parse_bill(bill) }
    link_congress_for(congress)
  end
  
  # Gets a single bill from Thomas
  def fetch_bill(congress, bill_number)
    # http://thomas.loc.gov/cgi-bin/bdquery/D?d104:2:./list/bss/d104HR.lst:@@@S
    url = URI.parse("http://thomas.loc.gov/cgi-bin/bdquery/D?d#{congress.fnumber}:#{bill_number}:./list/bss/d#{congress.fnumber}HR.lst:@@@S") # first we parse the URL
		puts "Trying to find bill #{bill_number.to_s} in congress #{congress.number.to_s}..." #to examine progress.
    response = get_http_response(url) # then we fetch the page
		tmp = response.body.scan(/H\.R\.(\d+)/)
		return if tmp.nil? or tmp.first.nil?
		name = tmp.first.first
		bill = Bill.find_or_create_by_name_and_congress_id(name, congress.id)
		bill.congress = congress
		bill.title = response.body.scan(/Title:<\/[Bb]> (.+)\n/).first.first
		bill.introduced_on = response.body.scan(/\(introduced (\d+\/\d+\/\d+)\)/).first.first
		
		# sponsors
		sponsors = response.body.scan(/>Rep (.+)<\/a> \[(..)-?(\d{0,2})\]\n/)
		sponsors.each do |sponsor|
		  rep = Representative.locate(sponsor[0])
		  if rep.state.nil? or rep.district.nil? then
		    rep.state = sponsor[1]
		    rep.district = sponsor[2]
		    rep.save
	    end
	    bill.sponsors << rep
    end
    
		# cosponsors
		if response.body.scan(/Cosponsors<\/a> \(\d+\)/)
			url.query[-1] = 'P'
			cosponsor_response = get_http_response(url) # fetch cosponsor page
			cosponsors = cosponsor_response.body.scan(/>Rep (.+)<\/a> \[(..)-?(\d{0,2})\]\n - \d+\/\d+\/\d+[\n<]/)
			cosponsors.each do |cosponsor|
			  rep = Representative.locate(cosponsor[0])
  		  if rep.state.nil? or rep.district.nil? then
  		    rep.state = cosponsor[1]
  		    rep.district = cosponsor[2]
  		    rep.save
  	    end
  	    bill.cosponsors << rep			  
		  end
		end
		
		# committees and subcommittees
    begin
      url.query[-1] = 'C'
      committee_response = get_http_response(url)
      committees = committee_response.body.scan(/>House +(.+)<\/a>/)
      subcommittees = committee_response.body.scan(/>Subcommittee on +(.+)<\/a>/)
      bill.committees.clear
      bill.subcommittees.clear
      committees.each { |committee| bill.committees << Committee.find_or_create_by_name(committee.first) unless committee.first.length>100}
      subcommittees.each { |subcommittee| bill.subcommittees << Subcommittee.find_or_create_by_name(subcommittee.first) }
      rescue
      print "Unusable match occurred\n"
    end
  
		# events
		events = response.body.scan(/<strong>(.+):<\/strong><dd>([[:print:]\n]+?)(?:<dt>|<\/dl>|<dl>)/) # here we scan the page for events, putting the date and event into an array
    Event.delete_all "bill_id = #{bill.id}" # delete all existing events associated with this bill as to not duplicate them
    events.each do |x|
      event = Event.new         
      event.date = x[0]
      event.title = x[1].gsub(/<\/?[^>]*>/, "").chomp  # remove html tags and newlines
      bill.events << event
      event.save
    end
    
    bill.save
  end
  
  public
  
  # Recreate the committee and subcommittee data based on the most up-to-date information from Thomas.
  def fix_committees
    Committee.delete_all
    Subcommittee.delete_all
    Bill.find(:all).each do |bill|
      begin
        url = URI.parse("http://thomas.loc.gov/cgi-bin/bdquery/D?d#{bill.congress.fnumber}:#{bill.name}:./list/bss/d#{bill.congress.fnumber}HR.lst:@@@C")
        committee_response = get_http_response(url)
        committees = committee_response.body.scan(/>House +(.+)<\/a>\s*<\/td>/)
        subcommittees = committee_response.body.scan(/>Subcommittee on +(.+)<\/a>\s*<\/td>/)
        bill.committees.clear
        bill.subcommittees.clear
        committees.each { |committee| bill.committees << Committee.find_or_create_by_name(committee.first) unless committee.first.length>100}
        subcommittees.each { |subcommittee| bill.subcommittees << Subcommittee.find_or_create_by_name(subcommittee.first) }
        rescue
        print "Unusable match occurred\n"
      end
    end
    redirect_to :action => "index"
  end
  
  def get_http_response(url)
    # try up to 5 times
    success = false
    attempt = 0
    response = nil
    while success == false && attempt < 5 do
      attempt = attempt + 1
      begin
        response = Net::HTTP.get_response(url) # then we fetch the page
      rescue StandardError
        puts "Error loading #{url} (attempt #{attempt}/5)"
      end
    end
    if response.nil?
      puts "Failed to load #{url}"
    end
    return response
  end

  def link_congress
    link_congress_for(Congress.find(params[:id]))
  end
  
  # Links the bills in the specified congress to its representatives, committees, and subcommittees.
  def link_congress_for(congress)
    congress.representatives.clear
    Representative.find(:all).each {|rep| congress.representatives << rep if Bill.find_by_sql("SELECT * FROM bills INNER JOIN bills_cosponsors ON bills.id = bills_cosponsors.bill_id WHERE (bills_cosponsors.representative_id = #{rep.id} and bills.congress_id = #{congress.id})").size > 0 or Bill.find_by_sql("SELECT * FROM bills INNER JOIN bills_sponsors ON bills.id = bills_sponsors.bill_id WHERE (bills_sponsors.representative_id = #{rep.id} and bills.congress_id = #{congress.id})").size > 0 }
    congress.committees.clear
    Committee.find(:all).each {|committee| congress.committees << committee if committee.bills.any? {|bill| bill.congress_id == congress.id } }
    congress.subcommittees.clear
    Subcommittee.find(:all).each {|subcommittee| congress.subcommittees << subcommittee if subcommittee.bills.any? {|bill| bill.congress_id == congress.id } }
    congress.save
    # redirect_to :action => "index"
  end
  
  public
  def fetch_amendments
    fetch_amendments_for(Congress.find(params[:id]))
  end
  
  # Gets the amendments for each bill in the congress from Thomas.
  def fetch_amendments_for(congress)
    events = Event.find(:all, :conditions => [ "Events.title LIKE '%H\.AMDT\.%' AND congress_id = ?", congress.id ], :include => :bill)
    amendments = []
    events.each do |event|
      amendment_number = event.title.scan(/H\.AMDT\.(\d+)/).first.first
      amendments << amendment_number unless amendments.include?(amendment_number)
    end
    amendments.each { |amendment| fetch_amendment(congress, amendment) }
    flash[:notice] = "#{amendments.size} amendments from the #{congress.number.ordinalize} were fetched"
    puts "#{amendments.size} amendments from the #{congress.number.ordinalize} were fetched"
    # redirect_to :action => "index"
  end
  
  private
  
  #Gets a single amendment from Thomas
  def fetch_amendment(congress, amendment_number)
    url = URI.parse("http://thomas.loc.gov/cgi-bin/bdquery/z?d#{congress.fnumber}:HZ#{amendment_number}:") # first we parse the URL
    response = get_http_response(url) # then we fetch the page
    #array = response.body.to_a # here we store in an array each line of the body of the page
    name = response.body.scan(/H\.AMDT\.(\d+)/).first.first
    puts "amendment #: #{name}"#"stuff: #{array[29].scan(/\./)}"
    amendment = Amendment.find_or_create_by_name_and_congress_id(name, congress.id)
    amendment.congress = congress

    bill_str = response.body.scan(/>Amends: <a href=.+>H\.R\.(\d+)<\/a>/).flatten.to_s
    puts "amends bill #{bill_str} for congress #{congress.fnumber}"
    amendment.bill = Bill.find_by_name_and_congress_id(bill_str, congress.id)
    amendment.offered_on = response.body.scan(/offered (\d+\/\d+\/\d+)/).to_s
    amendment.description = response.body.scan(/<p>AMENDMENT DESCRIPTION:<br \/>(.+)\n<p>/).flatten.to_s
    amendment.purpose = response.body.scan(/<p>AMENDMENT PURPOSE:<br \/>(.+)\n<p>/).flatten.to_s
    amendment.passed = false
    amendment.passed = true if response.body =~ /On agreeing to .+ Agreed to/ or response.body =~ /Amendment Passed/
    
    sponsors = response.body.scan(/>Rep (.+)<\/a> \[(..)-?(\d{0,2})\]\n/)
    sponsors.each do |sponsor|
      rep = Representative.locate(sponsor[0])
      if rep.state.nil? or rep.district.nil? then
        rep.state = sponsor[1]
        rep.district = sponsor[2]
        rep.save
      end
      amendment.sponsor = rep
    end

    amendment.save
  end
  
  public
  
  def rank_all
    Congress.find(:all).each { |congress| rank_congress(congress) }
    redirect_to :action => "index"
  end
  
  def rank_one
    rank_congress(Congress.find(params[:id]))
    redirect_to :action => "index"
  end
  
  private
  
  # Ranks a congress by assigning each bill its importance number (1-3) and its issue,
  # based on information in external files.
  def rank_congress(congress)
    important = []
    if File.exists?("important/#{congress.number}_House_important.txt") then
      File.open("important/#{congress.number}_House_important.txt").to_a.each do |bill|
        important << bill.chomp.to_i
      end
      
    end
    
    issues = []
    bill_issues = mda(39,5000)
    if (File.exists?("issues/names.txt")) then
      File.open("issues/names.txt").to_a.each do |i|
        issues.push(i[0...-1])
      end
      j=0
      issues.each do |i|
        if (File.exists?("issues/#{congress.number}_House_#{i}.txt")) then
          temp_array = []
          File.open("issues/#{congress.number}_House_#{i}.txt").to_a.each do |t|
            temp_array.push(t.to_i)
          end
          bill_issues[j] = temp_array
        end 
        j += 1
      end
    end
    
    congress.bills.each do |bill|
      bill.importance = RankingPhrase.importance(bill)#2
      #phrases.each { |phrase| bill.importance = 1 if bill.title.downcase.include?(phrase.downcase) }
      #exceptions.each { |exception| bill.importance = 2 if bill.title.downcase.include?(exception.downcase) } if bill.importance == 1
      #more_exceptions.each { |exception| bill.importance = 2 if bill.title.downcase =~ exception } if bill.importance == 1
      bill.importance += 1 if important.include?(bill.name)
      for j in 0...39
        bill.issue = issues[j] if bill_issues[j].include?(bill.name)
      end
      bill.save
    end
  end
  
  public
  def parse_congress
    Congress.find(params[:id]).bills.each { |bill| parse_bill(bill) }
    # redirect_to :action => "index"
  end
  
  def parse_all
    Bill.find(:all).each { |bill| parse_bill(bill) }
    # redirect_to :action => "index"    
  end
  
  private
  
  # Parses a bill's events by looking for specific text in its body, using regular expressions.
  def parse_bill(bill)
    bill.events.each do |event|
      if event.title =~ /The House Committee on Appropriations reported an original measure/ then
        bill.introduced_on = event.date if bill.introduced_on.nil?
        bill.referred_to_committee_on = event.date if bill.referred_to_committee_on.nil?
        bill.reported_by_committee_on = event.date if bill.reported_by_committee_on.nil?        
      end
      bill.forwarded_from_subcommittee_to_committee_on = event.date if event.title =~ /Forwarded by Subcommittee to Full Committee/ and bill.forwarded_from_subcommittee_to_committee_on.nil?
      bill.reported_by_committee_on = event.date if event.title =~ /Reported(( to House)? \(Amended\))? by the Committee/ or event.title =~ /Ordered to be Reported/ or event.title.downcase =~ /reported to house from the committee/ and bill.reported_by_committee_on.nil?
      bill.sent_to_conference_committee_on = event.date if event.title =~ /The Speaker appointed conferees/ or event.title =~ /Conference held/ or event.title.downcase =~ /agreed to request for conference/ or event.title =~ /agree to a conference Agreed/ and bill.sent_to_conference_committee_on.nil?
      bill.conference_committee_report_issued_on = event.date if event.title =~ /Conference report H. Rept. \d+-\d+ filed/ or event.title =~ /Conference Report/ or event.title =~ /Conference report filed in/ and bill.conference_committee_report_issued_on.nil?
      bill.conference_committee_passed_house_on = event.date if event.title =~ /On agreeing to the conference report Agreed/ or event.title =~ /House Agreed to Conference Report/ or event.title =~ /suspend the rules and agree to the conference report Agreed/ or event.title =~ /Conference report agreed to in House/ or event.title =~ /House agreed to conference report/ and bill.conference_committee_passed_house_on.nil?
      bill.conference_committee_passed_senate_on = event.date if event.title =~ /Senate agreed to( further)? conference report/ and bill.conference_committee_passed_senate_on.nil?
      bill.rule_reported_on = event.date if event.title =~ /Rules Committee Resolution H. Res. \d+ Reported to House/ or event.title =~ /Committee on Rules Granted/ or event.title =~ /Rules Committee Resolution .+ Reported/ and bill.rule_reported_on.nil?
      bill.rule_passed_on = event.date if event.title =~ /Rule H. Res. \d+ passed House/ or event.title =~ /Rule Passed House/ and bill.rule_passed_on.nil?
      bill.rules_suspended_on = event.date if event.title =~ /Considered under suspension of the rules/ or event.title =~ /Called up by House Under Suspension of Rules/ and bill.rules_suspended_on.nil?
      bill.considered_by_unanimous_consent_on = event.date if event.title =~ /Considered by unanimous consent/ or event.title =~ /Called up by House by Unanimous Consent/ and bill.considered_by_unanimous_consent_on.nil?
      bill.placed_on_union_calendar_on = event.date if event.title =~ /Placed on( the)? Union Calendar/ and bill.placed_on_union_calendar_on.nil?
      bill.placed_on_house_calendar_on = event.date if event.title =~ /Placed on( the)? House Calendar/ and bill.placed_on_house_calendar_on.nil?
      bill.placed_on_private_calendar_on = event.date if event.title =~ /Placed on( the)? Private Calendar/ and bill.placed_on_private_calendar_on.nil?
      bill.placed_on_corrections_calendar_on = event.date if event.title =~ /Placed on( the)? Corrections Calendar/ and bill.placed_on_corrections_calendar_on.nil?
      bill.placed_on_discharge_calendar_on = event.date if event.title =~ /Placed on( the)? Discharge Calendar/ and bill.placed_on_discharge_calendar_on.nil?
      bill.placed_on_consent_calendar_on = event.date if event.title =~ /Placed on( the)? Consent Calendar/ and bill.placed_on_consent_calendar_on.nil?
      bill.placed_on_senate_legislative_calendar_on = event.date if event.title =~ /Placed on( the)? Senate Legislative Calendar/ and bill.placed_on_senate_legislative_calendar_on.nil?      
      bill.passed_house_on = event.date if event.title =~ /On passage Passed/ or event.title =~ /On motion to suspend the rules and pass the bill(, as amended)? Agreed/ or event.title =~ /On motion that the House suspend the rules and agree to the Senate amendments? Agreed/ or event.title =~ /Passed House( \(Amended\))? by/ or event.title=~ /Passed House( \(Amended\))? by/ or event.title =~ /On motion to suspend the rules and pass the bill, as Agreed/ or event.title =~ /Passed.agreed to in House/ or event.title =~ /Measure passed House/ and bill.passed_house_on.nil?
      bill.failed_house_on = event.date if event.title =~ /Failed of Passage in House by Yea-Nay Vote/ or event.title =~ /Failed of Passage in House by Voice Vote/ or event.title =~ /Failed to Receive 2\/3's Vote to Suspend and Pass/ or event.title =~ /On passage Failed/ or event.title =~ /On motion to suspend the rules and pass the bill(, as amended)? Failed/ or event.title =~ /On motion that the House suspend the rules and agree to the Senate amendments? Failed/ and bill.failed_house_on.nil?
      bill.passed_senate_on = event.date if event.title =~ /Passed Senate/ or event.title =~ /Received in the Senate, read twice, considered, read the third time, and passed/ or event.title =~ /passed without amendment by Voice Vote/ or event.title =~ /Passed.agreed to in Senate/ or event.title =~ /Measure passed Senate/ and bill.passed_senate_on.nil?
      bill.received_in_senate_on = event.date if event.title =~ /Received in the Senate/ or event.title =~ /Reported to Senate by Senator/ or event.title =~ /Reported by Senator/ and bill.received_in_senate_on.nil?
      bill.referred_to_committee_on = event.date if event.title =~ /Referred( sequentially)? to the( House)? Committee/ or event.title =~ /Referred jointly to the House Committee/ or event.title =~ /Referred to House Committee/ and (bill.referred_to_committee_on.nil? or event.date < bill.referred_to_committee_on)
      bill.referred_to_subcommittee_on = event.date if event.title =~ /Referred to( the)? Subcommittee/ and bill.referred_to_subcommittee_on.nil?
      bill.committee_hearing_held_on = event.date if event.title == "Committee Hearings Held." or event.title =~ /Field Hearings Held/ and bill.committee_hearing_held_on.nil?
      bill.subcommittee_hearing_held_on = event.date if event.title == "Subcommittee Hearings Held." and bill.subcommittee_hearing_held_on.nil?
      bill.committee_markup_held_on = event.date if event.title == "Committee Consideration and Mark-up Session Held." and bill.committee_markup_held_on.nil?
      bill.subcommittee_markup_held_on = event.date if event.title == "Subcommittee Consideration and Mark-up Session Held." and bill.subcommittee_markup_held_on.nil?
      bill.presented_to_president_on = event.date if event.title =~ /Presented to President/ or event.title.downcase =~ /measure presented to president/
      bill.vetoed_by_president_on = event.date if event.title =~ /Vetoed by President/
      bill.signed_by_president_on = event.date if event.title =~ /Signed by President/
      bill.house_veto_override_failed_on = event.date if event.title =~ /Failed of Passage in House Over Veto/ or event.title =~ /On passage, the objections of the President to the contrary notwithstanding Failed/ or event.title =~ /Motion to override veto failed of passage in House/ and bill.house_veto_override_failed_on.nil?
      bill.house_veto_override_on = event.date if event.title =~ /Two-thirds of the Members present having voted in the affirmative the bill is passed/ or event.title.downcase =~ /passed house over veto/ and bill.house_veto_override_on.nil?
      bill.senate_veto_override_failed_on = event.date if event.title =~ /Failed of passage in Senate over veto/ or event.title =~ /Motion to override veto failed of passage in Senate/ and bill.senate_veto_override_failed_on.nil?
      bill.senate_veto_override_on = event.date if event.title.downcase =~ /passed senate over veto/ and bill.senate_veto_override_on.nil?
      bill.became_law_on = event.date if event.title.downcase =~ /public law/ and bill.became_law_on.nil?
    end
    bill.passed = false
    bill.passed = true if !bill.became_law_on.nil? or (!bill.signed_by_president_on.nil? and bill.vetoed_by_president_on.nil?) or (!bill.house_veto_override_on.nil? and !bill.senate_veto_override_on.nil?)
    bill.save
  end


end