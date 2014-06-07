class ReportController < ApplicationController
  require 'zip/zip'
    
  private
  def zip(data)
    zipfile = "rubyzip-#{rand 32768}" 
    Zip::ZipOutputStream::open(zipfile) do |io|
      count = 0
      data.each do |d, n|
        io.put_next_entry(("#{n}" or "#{count += 1}.txt"))
        io.write d
      end
    end
    zippy = File.open(zipfile).read
    #File.delete(zipfile)
    zippy 
  end
  
  def write_report(data, subfolder,category)
    count = 0
    Dir.chdir("Reports")
    if !(Dir.entries(Dir.pwd).include?(subfolder)) then Dir.mkdir(subfolder) end
    Dir.chdir(subfolder)
    if !(Dir.entries(Dir.pwd).include?(category)) then Dir.mkdir(category) end
    Dir.chdir(category)
    
    data.each do |d,n|
      f = File.new(("#{n}.csv" or "#{count += 1}.csv"),"w")
      f.write d
      f.close
    end
    
    Dir.chdir("../../..")
  end
  
  public
  def generate
    congresses = Congress.find(params[:checkbox].delete_if { |k,v| v == '0' }.keys, :order => :number)
    data = []
    congresses.each do |congress|
      generate_bills(congress, data) if params[:report][:bills] == "1"
      write_report(data, congress.number.to_s,"Bills") if data != []
      data = []
      generate_amendments(congress, data) if params[:report][:amendments] == "1"
      write_report(data, congress.number.to_s,"Amendments") if data != []
      data = []
      generate_reps(congress, data) if params[:report][:reps] == "1"
      write_report(data, congress.number.to_s,"Reps") if data != []
      data = []
      generate_repssubcomm(congress, data) if params[:report][:reps] == "1"
      write_report(data, congress.number.to_s,"RepsSubcomm") if data != []
      data = []
      generate_reps_bills(congress, data) if params[:report][:repsbills] == "1"
      write_report(data, congress.number.to_s,"Reps-Bills") if data != []
      data = []
    end
    #send_data zip(data), :filename => "reports.zip"
    flash[:notice] = "Reports generated successfully."
    redirect_to :controller=>'congress'
  end
  
  private
	
  def generate_bills(congress, data)
    @representatives = congress.representatives
    @committees = congress.committees
    @subcommittees = congress.subcommittees    
    1.upto(3) do |importance|
      bills = Bill.find(:all, :conditions => { :congress_id => congress.id, :importance => importance }, :order => :name )
      0.upto((bills.size.to_f / 250.0).ceil - 1) do |batch|
        @bills = bills.values_at((batch * 250)..((batch + 1) * 250 - 1)).compact
        data << [ render_to_string(:action => "bills", :layout => false), "#{congress.number.ordinalize}-bills-#{if importance==1 then "unimportant" elsif importance==2 then "regular" elsif importance==3 then "important" end}-#{batch}" ] if @bills.size > 0
      end
    end
  end
  
  def generate_amendments(congress, data)
    amendments = Amendment.find(:all, :conditions => { :congress_id => congress.id }, :order => 'amendments.name', :include => :bill )
    @representatives = congress.representatives
    @committees = congress.committees
    @subcommittees = congress.subcommittees
    @sponsoring_committees = @committees.partition {|c| c.amendments.size > 0 }.first
    0.upto((amendments.size.to_f / 250.0).ceil - 1) do |batch|
      @amendments = amendments.values_at((batch * 250)..((batch + 1) * 250 - 1)).compact
      @bills = @amendments.collect {|a| a.bill }
      data << [ render_to_string(:action => "amendments", :layout => false), "#{congress.number.ordinalize}-amendments-#{batch}" ] if @amendments.size > 0
    end
  end
  
  def generate_reps_bills(congress, data)
    congress_id = congress.id
    @representatives = congress.representatives.sort {|x,y| x.last_name <=> y.last_name }
    @columns = [
      'Representative',
      "Unimportant Sponsored Bills (passed)",
      "Unimportant Sponsored Bills (failed)",
      "Unimportant Cosponsored Bills (passed)",
      "Unimportant Cosponsored Bills (failed)",
      "Regular Sponsored Bills (passed)",
      "Regular Sponsored Bills (failed)",
      "Regular Cosponsored Bills (passed)",
      "Regular Cosponsored Bills (failed)",
      "Important Sponsored Bills (passed)",
      "Important Sponsored Bills (failed)",
      "Important Cosponsored Bills (passed)",
      "Important Cosponsored Bills (failed)",
      "Amendments (passed)",
      "Amendments (failed)"
      ]
    @data = []
    @representatives.each do |rep|
      a = []
      a << rep.name
      1.upto(3) do |importance|
        a << rep.passed_bills.reject {|b| b.congress_id != congress_id or b.importance != importance }.collect {|b| b.name }.join(", ")
        a << rep.failed_bills.reject {|b| b.congress_id != congress_id or b.importance != importance }.collect {|b| b.name }.join(", ")
        a << rep.passed_cosponsored_bills.reject {|b| b.congress_id != congress_id or b.importance != importance }.collect {|b| b.name }.join(", ")
        a << rep.failed_cosponsored_bills.reject {|b| b.congress_id != congress_id or b.importance != importance }.collect {|b| b.name }.join(", ")
      end
      #a << rep.passed_amendments.reject {|a| a.bill.congress_id != congress_id }.collect {|a| a.name }.sort.join(", ")
      #a << rep.failed_amendments.reject {|a| a.bill.congress_id != congress_id }.collect {|a| a.name }.sort.join(", ")      
      @data << a
    end
    data << [ render_to_string(:action => "reps", :layout => false), "#{congress.number.ordinalize}-reps_bills" ]
  end
  
  def generate_reps(congress, data)
    @columns = reps_columns
    representatives = congress.representatives.sort {|x,y| x.last_name <=> y.last_name }
    all_bills = congress.bills
    1.upto(3) do |importance|
      bills_importance = all_bills.reject { |b| b.importance != importance }
      ("all".to_a + congress.committees).each do |committee|
        bills = Array.new(bills_importance)
        bills.reject! { |b| !b.committees.include?(committee) } if committee.class == Committee
        amended_bills = bills.reject { |b| b.amendments.size == 0 }
        @data = []
        representatives.each do |rep|
          rep_data = []
          rep_data << "#{rep.last_name}, #{rep.first_name}"
          rep_sponsored_bills = bills.reject { |b| !b.sponsors.include? rep }
          rep_sponsored_bills_unamended = rep_sponsored_bills.reject { |b| b.amendments.any? { |a| a.passed == true } }
          rep_cosponsored_bills = bills.reject { |b| !b.cosponsors.include? rep }
          rep_cosponsored_bills_unamended = rep_cosponsored_bills.reject { |b| b.amendments.any? { |a| a.passed == true } }
          rep_items(rep_data, rep_sponsored_bills)
          rep_items(rep_data, rep_sponsored_bills_unamended)
          rep_items(rep_data, rep_cosponsored_bills)
          rep_items(rep_data, rep_cosponsored_bills_unamended)
          # amendment_bills = amended_bills.reject { |b| b.amendments.any? { |a| a.sponsor_type != "Representative" or a.sponsor_id != rep.id } }
          # amendment_bills_passed = amendment_bills.reject { |b| b.amendments.any? { |a| a.passed != true } }
          amendment_bills = []
          amendment_bills_passed = []
          amended_bills.each { |b| amendment_bills << b if b.amendments.any? { |a| a.sponsor_type == "Representative" and a.sponsor_id == rep.id } }
          amended_bills.each { |b| amendment_bills_passed << b if b.amendments.any? { |a| a.sponsor_type == "Representative" and a.sponsor_id == rep.id and a.passed == true } }
          rep_items(rep_data, amendment_bills)
          rep_items(rep_data, amendment_bills_passed)
          rep_data << amendment_bills.size
          rep_data << amendment_bills_passed.size
          rep_data << amendment_bills.inject(0) { |sum, b| sum + b.amendments.find_all { |a| a.sponsor_type == "Representative" and a.sponsor_id == rep.id }.size }
          rep_data << amendment_bills_passed.inject(0) { |sum, b| sum + b.amendments.find_all { |a| a.sponsor_type == "Representative" and a.sponsor_id == rep.id and a.passed == true }.size }
          
          score = 0.0
          amendment_bills_passed.each do |b|
            score += ( b.amendments.find_all { |a| a.sponsor_type == "Representative" and a.sponsor_id == rep.id and a.passed == true }.size.to_f / b.passed_amendments.size.to_f )
          end
          rep_data << score

          @data << rep_data
        end
        data << [ render_to_string(:action => "reps", :layout => false), "#{congress.number.ordinalize}-reps-#{if importance==1 then "unimportant" elsif importance==2 then "regular" elsif importance==3 then "important" end}#{"-" + committee.name if committee.class == Committee}" ]        
      end
    end
  end
  
  def generate_repssubcomm(congress, data)
    @columns = reps_columns
    representatives = congress.representatives.sort {|x,y| x.last_name <=> y.last_name }
    all_bills = congress.bills
    1.upto(3) do |importance|
      bills_importance = all_bills.reject { |b| b.importance != importance }
      ("all".to_a + congress.subcommittees).each do |subcommittee|
        bills = Array.new(bills_importance)
        bills.reject! { |b| !b.subcommittees.include?(subcommittee) } if subcommittee.class == Subcommittee
        amended_bills = bills.reject { |b| b.amendments.size == 0 }
        @data = []
        representatives.each do |rep|
          rep_data = []
          rep_data << "#{rep.last_name}, #{rep.first_name}"
          rep_sponsored_bills = bills.reject { |b| !b.sponsors.include? rep }
          rep_sponsored_bills_unamended = rep_sponsored_bills.reject { |b| b.amendments.any? { |a| a.passed == true } }
          rep_cosponsored_bills = bills.reject { |b| !b.cosponsors.include? rep }
          rep_cosponsored_bills_unamended = rep_cosponsored_bills.reject { |b| b.amendments.any? { |a| a.passed == true } }
          rep_items(rep_data, rep_sponsored_bills)
          rep_items(rep_data, rep_sponsored_bills_unamended)
          rep_items(rep_data, rep_cosponsored_bills)
          rep_items(rep_data, rep_cosponsored_bills_unamended)
          # amendment_bills = amended_bills.reject { |b| b.amendments.any? { |a| a.sponsor_type != "Representative" or a.sponsor_id != rep.id } }
          # amendment_bills_passed = amendment_bills.reject { |b| b.amendments.any? { |a| a.passed != true } }
          amendment_bills = []
          amendment_bills_passed = []
          amended_bills.each { |b| amendment_bills << b if b.amendments.any? { |a| a.sponsor_type == "Representative" and a.sponsor_id == rep.id } }
          amended_bills.each { |b| amendment_bills_passed << b if b.amendments.any? { |a| a.sponsor_type == "Representative" and a.sponsor_id == rep.id and a.passed == true } }
          rep_items(rep_data, amendment_bills)
          rep_items(rep_data, amendment_bills_passed)
          rep_data << amendment_bills.size
          rep_data << amendment_bills_passed.size
          rep_data << amendment_bills.inject(0) { |sum, b| sum + b.amendments.find_all { |a| a.sponsor_type == "Representative" and a.sponsor_id == rep.id }.size }
          rep_data << amendment_bills_passed.inject(0) { |sum, b| sum + b.amendments.find_all { |a| a.sponsor_type == "Representative" and a.sponsor_id == rep.id and a.passed == true }.size }
          
          score = 0.0
          amendment_bills_passed.each do |b|
            score += ( b.amendments.find_all { |a| a.sponsor_type == "Representative" and a.sponsor_id == rep.id and a.passed == true }.size.to_f / b.passed_amendments.size.to_f )
          end
          rep_data << score

          @data << rep_data
        end
        data << [ render_to_string(:action => "reps", :layout => false), "#{congress.number.ordinalize}-reps-#{if importance==1 then "unimportant" elsif importance==2 then "regular" elsif importance==3 then "important" end}#{"-" + subcommittee.name if subcommittee.class == Subcommittee}" ]        
      end
    end
  end
  
  def rep_items(array, rep_bills)
    array << rep_bills.reject {|bill| bill.introduced_on.nil? }.size
    array << rep_bills.reject {|bill| bill.referred_to_committee_on.nil? }.size
    array << rep_bills.reject {|bill| bill.committee_hearing_held_on.nil? }.size
    array << rep_bills.reject {|bill| bill.committee_markup_held_on.nil? }.size
    array << rep_bills.reject {|bill| bill.reported_by_committee_on.nil? }.size
    array << rep_bills.reject {|bill| bill.referred_to_subcommittee_on.nil? }.size
    array << rep_bills.reject {|bill| bill.subcommittee_hearing_held_on.nil? }.size
    array << rep_bills.reject {|bill| bill.subcommittee_markup_held_on.nil? }.size
    array << rep_bills.reject {|bill| bill.forwarded_from_subcommittee_to_committee_on.nil? }.size
    array << rep_bills.reject {|bill| bill.committee_hearing_held_on.nil? and bill.committee_markup_held_on.nil? and bill.reported_by_committee_on.nil? and bill.subcommittee_hearing_held_on.nil? and bill.subcommittee_markup_held_on.nil? and bill.forwarded_from_subcommittee_to_committee_on.nil? }.size
    array << rep_bills.reject {|bill| bill.reported_by_committee_on.nil? and bill.rule_reported_on.nil? and bill.rules_suspended_on.nil? and bill.considered_by_unanimous_consent_on.nil? and bill.passed_house_on.nil? and bill.failed_house_on.nil? and bill.received_in_senate_on.nil? and bill.placed_on_union_calendar_on.nil? and bill.placed_on_house_calendar_on.nil? and bill.placed_on_private_calendar_on.nil? and bill.placed_on_corrections_calendar_on.nil? and bill.placed_on_discharge_calendar_on.nil? and bill.placed_on_consent_calendar_on.nil? and bill.placed_on_senate_legislative_calendar_on.nil? }.size
    array << rep_bills.reject {|bill| bill.placed_on_union_calendar_on.nil? }.size
    array << rep_bills.reject {|bill| bill.placed_on_house_calendar_on.nil? }.size
    array << rep_bills.reject {|bill| bill.placed_on_private_calendar_on.nil? }.size
    array << rep_bills.reject {|bill| bill.placed_on_corrections_calendar_on.nil? }.size
    array << rep_bills.reject {|bill| bill.placed_on_discharge_calendar_on.nil? }.size
    array << rep_bills.reject {|bill| bill.rule_reported_on.nil? }.size
    array << rep_bills.reject {|bill| bill.rule_passed_on.nil? }.size
    array << rep_bills.reject {|bill| bill.rules_suspended_on.nil? }.size
    array << rep_bills.reject {|bill| bill.considered_by_unanimous_consent_on.nil? }.size
    array << rep_bills.reject {|bill| bill.passed_house_on.nil? }.size
    array << rep_bills.reject {|bill| bill.failed_house_on.nil? }.size
    array << rep_bills.reject {|bill| bill.received_in_senate_on.nil? }.size
    array << rep_bills.reject {|bill| bill.passed_senate_on.nil? }.size
    array << rep_bills.reject {|bill| bill.failed_senate_on.nil? }.size
    array << rep_bills.reject {|bill| bill.sent_to_conference_committee_on.nil? }.size
    array << rep_bills.reject {|bill| bill.conference_committee_report_issued_on.nil? }.size
    array << rep_bills.reject {|bill| bill.conference_committee_passed_house_on.nil? }.size
    array << rep_bills.reject {|bill| bill.conference_committee_passed_senate_on.nil? }.size
    array << rep_bills.reject {|bill| bill.presented_to_president_on.nil? }.size
    array << rep_bills.reject {|bill| bill.signed_by_president_on.nil? }.size
    array << rep_bills.reject {|bill| bill.vetoed_by_president_on.nil? }.size
    array << rep_bills.reject {|bill| bill.house_veto_override_on.nil? }.size
    array << rep_bills.reject {|bill| bill.senate_veto_override_on.nil? }.size
    array << rep_bills.reject {|bill| bill.house_veto_override_failed_on.nil? }.size
    array << rep_bills.reject {|bill| bill.senate_veto_override_failed_on.nil? }.size
    array << rep_bills.reject {|bill| bill.passed == false }.size
  end
  
  def reps_columns
    @columns = [
      'Name',
      '(Sponsored) Introduced',
      '(Sponsored) Referred To Committee',
      '(Sponsored) Committee Hearing Held',
      '(Sponsored) Committee markup held',
      '(Sponsored) Reported by Committee',
      '(Sponsored) Referred to Subcommittee',
      '(Sponsored) Subcommittee hearing held',
      '(Sponsored) Subcommittee markup held',
      '(Sponsored) Forwarded from Subcommittee to Committee',
      '(Sponsored) Action in committee',
      '(Sponsored) Action beyond committee',
      '(Sponsored) Placed on Union Calendar',
      '(Sponsored) Placed on House Calendar',
      '(Sponsored) Placed on Private Calendar',
      '(Sponsored) Placed on Corrections Calendar',
      '(Sponsored) Placed on Discharge Calendar',
      '(Sponsored) Rules reported',
      '(Sponsored) Rules passed',
      '(Sponsored) Rules suspended',
      '(Sponsored) Considered by unanimous consent',
      '(Sponsored) Passed House',
      '(Sponsored) Failed House',
      '(Sponsored) Received in Senate',
      '(Sponsored) Passed Senate',
      '(Sponsored) Failed Senate',
      '(Sponsored) Sent to conference committee',
      '(Sponsored) Conference committee report issued',
      '(Sponsored) Conference committee report passed House',
      '(Sponsored) Conference committee report passed Senate',      
      '(Sponsored) Presented to President',
      '(Sponsored) Signed by President',
      '(Sponsored) Vetoed by President',
      '(Sponsored) House veto override successful',
      '(Sponsored) Senate veto override successful',
      "(Sponsored) House veto override failed",
      "(Sponsored) Senate veto override failed",
      "(Sponsored) Became law",
      '(Sponsored-Unamended) Introduced',
      '(Sponsored-Unamended) Referred To Committee',
      '(Sponsored-Unamended) Committee Hearing Held',
      '(Sponsored-Unamended) Committee markup held',
      '(Sponsored-Unamended) Reported by Committee',
      '(Sponsored-Unamended) Referred to Subcommittee',
      '(Sponsored-Unamended) Subcommittee hearing held',
      '(Sponsored-Unamended) Subcommittee markup held',
      '(Sponsored-Unamended) Forwarded from Subcommittee to Committee',
      '(Sponsored-Unamended) Action in committee',
      '(Sponsored-Unamended) Action beyond committee',
      '(Sponsored-Unamended) Placed on Union Calendar',
      '(Sponsored-Unamended) Placed on House Calendar',
      '(Sponsored-Unamended) Placed on Private Calendar',
      '(Sponsored-Unamended) Placed on Corrections Calendar',
      '(Sponsored-Unamended) Placed on Discharge Calendar',
      '(Sponsored-Unamended) Rules reported',
      '(Sponsored-Unamended) Rules passed',
      '(Sponsored-Unamended) Rules suspended',
      '(Sponsored-Unamended) Considered by unanimous consent',
      '(Sponsored-Unamended) Passed House',
      '(Sponsored-Unamended) Failed House',
      '(Sponsored-Unamended) Received in Senate',
      '(Sponsored-Unamended) Passed Senate',
      '(Sponsored-Unamended) Failed Senate',
      '(Sponsored-Unamended) Sent to conference committee',
      '(Sponsored-Unamended) Conference committee report issued',
      '(Sponsored-Unamended) Conference committee report passed House',
      '(Sponsored-Unamended) Conference committee report passed Senate',      
      '(Sponsored-Unamended) Presented to President',
      '(Sponsored-Unamended) Signed by President',
      '(Sponsored-Unamended) Vetoed by President',
      '(Sponsored-Unamended) House veto override successful',
      '(Sponsored-Unamended) Senate veto override successful',
      "(Sponsored-Unamended) House veto override failed",
      "(Sponsored-Unamended) Senate veto override failed",
      "(Sponsored-Unamended) Became law",
      "(Cosponsored) Introduced",
      "(Cosponsored) Referred To Committee",
      "(Cosponsored) Committee Hearing Held",
      "(Cosponsored) Committee markup held",
      "(Cosponsored) Reported by Committee",
      "(Cosponsored) Referred to Subcommittee",
      "(Cosponsored) Subcommittee hearing held",
      "(Cosponsored) Subcommittee markup held",
      "(Cosponsored) Forwarded from Subcommittee to Committee",
      "(Cosponsored) Action in committee",
      "(Cosponsored) Action beyond committee",
      "(Cosponsored) Placed on Union Calendar",
      "(Cosponsored) Placed on House Calendar",
      "(Cosponsored) Placed on Private Calendar",
      "(Cosponsored) Placed on Corrections Calendar",
      "(Cosponsored) Placed on Discharge Calendar",
      "(Cosponsored) Rules reported",
      "(Cosponsored) Rules passed",
      "(Cosponsored) Rules suspended",
      "(Cosponsored) Considered by unanimous consent",
      "(Cosponsored) Passed House",
      "(Cosponsored) Failed House",
      "(Cosponsored) Received in Senate",
      "(Cosponsored) Passed Senate",
      "(Cosponsored) Failed Senate",
      "(Cosponsored) Sent to conference committee",
      "(Cosponsored) Conference committee report issued",
      "(Cosponsored) Conference committee report passed House",
      "(Cosponsored) Conference committee report passed Senate",
      "(Cosponsored) Presented to President",
      "(Cosponsored) Signed by President",
      "(Cosponsored) Vetoed by President",
      "(Cosponsored) House veto override successful",
      "(Cosponsored) Senate veto override successful",
      "(Cosponsored) House veto override failed",
      "(Cosponsored) Senate veto override failed",
      "(Cosponsored) Became law",
      "(Cosponsored-Unamended) Introduced",
      "(Cosponsored-Unamended) Referred To Committee",
      "(Cosponsored-Unamended) Committee Hearing Held",
      "(Cosponsored-Unamended) Committee markup held",
      "(Cosponsored-Unamended) Reported by Committee",
      "(Cosponsored-Unamended) Referred to Subcommittee",
      "(Cosponsored-Unamended) Subcommittee hearing held",
      "(Cosponsored-Unamended) Subcommittee markup held",
      "(Cosponsored-Unamended) Forwarded from Subcommittee to Committee",
      "(Cosponsored-Unamended) Action in committee",
      "(Cosponsored-Unamended) Action beyond committee",
      "(Cosponsored-Unamended) Placed on Union Calendar",
      "(Cosponsored-Unamended) Placed on House Calendar",
      "(Cosponsored-Unamended) Placed on Private Calendar",
      "(Cosponsored-Unamended) Placed on Corrections Calendar",
      "(Cosponsored-Unamended) Placed on Discharge Calendar",
      "(Cosponsored-Unamended) Rules reported",
      "(Cosponsored-Unamended) Rules passed",
      "(Cosponsored-Unamended) Rules suspended",
      "(Cosponsored-Unamended) Considered by unanimous consent",
      "(Cosponsored-Unamended) Passed House",
      "(Cosponsored-Unamended) Failed House",
      "(Cosponsored-Unamended) Received in Senate",
      "(Cosponsored-Unamended) Passed Senate",
      "(Cosponsored-Unamended) Failed Senate",
      "(Cosponsored-Unamended) Sent to conference committee",
      "(Cosponsored-Unamended) Conference committee report issued",
      "(Cosponsored-Unamended) Conference committee report passed House",
      "(Cosponsored-Unamended) Conference committee report passed Senate",
      "(Cosponsored-Unamended) Presented to President",
      "(Cosponsored-Unamended) Signed by President",
      "(Cosponsored-Unamended) Vetoed by President",
      "(Cosponsored-Unamended) House veto override successful",
      "(Cosponsored-Unamended) Senate veto override successful",
      "(Cosponsored-Unamended) House veto override failed",
      "(Cosponsored-Unamended) Senate veto override failed",
      "(Cosponsored-Unamended) Became law",
      "(Amended) Introduced",
      "(Amended) Referred To Committee",
      "(Amended) Committee Hearing Held",
      "(Amended) Committee markup held",
      "(Amended) Reported by Committee",
      "(Amended) Referred to Subcommittee",
      "(Amended) Subcommittee hearing held",
      "(Amended) Subcommittee markup held",
      "(Amended) Forwarded from Subcommittee to Committee",
      "(Amended) Action in committee",
      "(Amended) Action beyond committee",
      "(Amended) Placed on Union Calendar",
      "(Amended) Placed on House Calendar",
      "(Amended) Placed on Private Calendar",
      "(Amended) Placed on Corrections Calendar",
      "(Amended) Placed on Discharge Calendar",
      "(Amended) Rules reported",
      "(Amended) Rules passed",
      "(Amended) Rules suspended",
      "(Amended) Considered by unanimous consent",
      "(Amended) Passed House",
      "(Amended) Failed House",
      "(Amended) Received in Senate",
      "(Amended) Passed Senate",
      "(Amended) Failed Senate",
      "(Amended) Sent to conference committee",
      "(Amended) Conference committee report issued",
      "(Amended) Conference committee report passed House",
      "(Amended) Conference committee report passed Senate",
      "(Amended) Presented to President",
      "(Amended) Signed by President",
      "(Amended) Vetoed by President",
      "(Amended) House veto override successful",
      "(Amended) Senate veto override successful",
      "(Amended) House veto override failed",
      "(Amended) Senate veto override failed",
      "(Amended) Became law",
      "(Amended Successfully) Introduced",
      "(Amended Successfully) Referred To Committee",
      "(Amended Successfully) Committee Hearing Held",
      "(Amended Successfully) Committee markup held",
      "(Amended Successfully) Reported by Committee",
      "(Amended Successfully) Referred to Subcommittee",
      "(Amended Successfully) Subcommittee hearing held",
      "(Amended Successfully) Subcommittee markup held",
      "(Amended Successfully) Forwarded from Subcommittee to Committee",
      "(Amended Successfully) Action in committee",
      "(Amended Successfully) Action beyond committee",
      "(Amended Successfully) Placed on Union Calendar",
      "(Amended Successfully) Placed on House Calendar",
      "(Amended Successfully) Placed on Private Calendar",
      "(Amended Successfully) Placed on Corrections Calendar",
      "(Amended Successfully) Placed on Discharge Calendar",
      "(Amended Successfully) Rules reported",
      "(Amended Successfully) Rules passed",
      "(Amended Successfully) Rules suspended",
      "(Amended Successfully) Considered by unanimous consent",
      "(Amended Successfully) Passed House",
      "(Amended Successfully) Failed House",
      "(Amended Successfully) Received in Senate",
      "(Amended Successfully) Passed Senate",
      "(Amended Successfully) Failed Senate",
      "(Amended Successfully) Sent to conference committee",
      "(Amended Successfully) Conference committee report issued",
      "(Amended Successfully) Conference committee report passed House",
      "(Amended Successfully) Conference committee report passed Senate",
      "(Amended Successfully) Presented to President",
      "(Amended Successfully) Signed by President",
      "(Amended Successfully) Vetoed by President",
      "(Amended Successfully) House veto override successful",
      "(Amended Successfully) Senate veto override successful",
      "(Amended Successfully) House veto override failed",
      "(Amended Successfully) Senate veto override failed",
      "(Amended Successfully) Became law",
      "Bills with Amendments Offered",
      "Bills with Amendments Passed",
      "Total Amendments Offered",
      "Total Amendments Passed",
      "Amendment Score",
      ]
    end
  
end
