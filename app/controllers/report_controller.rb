#This class contains all of the logic for creating reports.

class ReportController < ApplicationController
  require 'zip/zip'
  require 'thread'
    
  private
  
  # Ostensibly writes the report data to a zip file, which is then available to download.
  # However, it doesn't work right now.
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
  
  # Instead, we'll just write the reports directly onto the file system. Since the zip
  # method was doint this anyway and then asking you to download it, this should be faster.
  def write_report(data, subfolder,category)
    count = 0
    Dir.chdir("Reports")
    
    # Creates the subfolders if they don't already exist
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
  
  # One at a time, generate the data for each kind of report if it was chosen on the form,
  # then write that data to the file system, if there was any. Finally, clear the data for the
  # next report.
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
      generate_repssubcomm(congress, data) if params[:report][:reps_subcomm] == "1"
      write_report(data, congress.number.to_s,"RepsSubcomm") if data != []
      
      data = []
      generate_repsreferrals(congress, data) if params[:report][:reps_referrals] == "1"
      write_report(data, congress.number.to_s,"RepsReferrals") if data != []
      
      data = []
      generate_repsissues(congress, data) if params[:report][:reps_issues] == "1"
      write_report(data, congress.number.to_s,"RepsIssues") if data != []
      
      data = []
      generate_reps_bills(congress, data) if params[:report][:reps_bills] == "1"
      write_report(data, congress.number.to_s,"Reps-Bills") if data != []
      
      data = []
    end
    
    # Put this line instead of write_report to use the zip method instead (not recommended).
    #send_data zip(data), :filename => "reports.zip"
    flash[:notice] = "Reports generated successfully."
    redirect_to :controller=>'congress'
  end
  
  private
	
  # Uses the file views/report/bills.rhtml to generate the csv-format output string
  # for the specified congress
  def generate_bills(congress, data)
    @representatives = congress.representatives
    @committees = congress.committees
    @subcommittees = congress.subcommittees
    
    # List in order of importance
    1.upto(3) do |importance|
      bills = Bill.find(:all, :conditions => { :congress_id => congress.id, :importance => importance }, :order => :name )
      
      # Generates the report in batches of 250 bills to avoid memory problems
      0.upto((bills.size.to_f / 250.0).ceil - 1) do |batch|
        @bills = bills.values_at((batch * 250)..((batch + 1) * 250 - 1)).compact
        data << [ render_to_string(:action => "bills", :layout => false), "#{congress.number.ordinalize}-bills-#{if importance==1 then "unimportant" elsif importance==2 then "regular" elsif importance==3 then "important" end}-#{batch}" ] if @bills.size > 0
      end
    end
  end
  
  # Similarly, uses the amendment view file to generate the csv-format amendments report
  # for the specified congress
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
  
  # Generates csv-format string for reps-bills. Maybe use a view file for this as well, for
  # consistency.
  def generate_reps_bills(congress, data)
    congress_id = congress.id
    @representatives = congress.representatives.sort {|x,y| x.last_name <=> y.last_name }
    @columns = [
      'Representative',
      "Unimportant Sponsored Bills (passed)",
      "Unimportant Sponsored Bills (failed)",
      #"Unimportant Cosponsored Bills (passed)",
      #"Unimportant Cosponsored Bills (failed)",
      "Regular Sponsored Bills (passed)",
      "Regular Sponsored Bills (failed)",
      #"Regular Cosponsored Bills (passed)",
      #"Regular Cosponsored Bills (failed)",
      "Important Sponsored Bills (passed)",
      "Important Sponsored Bills (failed)"#,
      #"Important Cosponsored Bills (passed)",
      #"Important Cosponsored Bills (failed)",
      #"Amendments (passed)",
      #"Amendments (failed)"
      ]
    @data = []
    @representatives.each do |rep|
      a = []
      a << rep.name
      1.upto(3) do |importance|
        a << rep.passed_bills.reject {|b| b.congress_id != congress_id or b.importance != importance }.collect {|b| b.name }.join(", ")
        a << rep.failed_bills.reject {|b| b.congress_id != congress_id or b.importance != importance }.collect {|b| b.name }.join(", ")
        #a << rep.passed_cosponsored_bills.reject {|b| b.congress_id != congress_id or b.importance != importance }.collect {|b| b.name }.join(", ")
        #a << rep.failed_cosponsored_bills.reject {|b| b.congress_id != congress_id or b.importance != importance }.collect {|b| b.name }.join(", ")
      end
      #a << rep.passed_amendments.reject {|a| a.bill.congress_id != congress_id }.collect {|a| a.name }.sort.join(", ")
      #a << rep.failed_amendments.reject {|a| a.bill.congress_id != congress_id }.collect {|a| a.name }.sort.join(", ")      
      @data << a
    end
    data << [ render_to_string(:action => "reps", :layout => false), "#{congress.number.ordinalize}-reps_bills" ]
  end
  
  # Generates csv-format string for the representatives report
  # Future maintenance: clean/generalize for the other variations of this report (below).
  def generate_reps(congress, data)
    @columns = reps_columns
    representatives = congress.representatives.sort {|x,y| x.last_name <=> y.last_name }
    all_bills = congress.bills
    
    # Do each importance level in order
    1.upto(3) do |importance|
      bills_importance = all_bills.reject { |b| b.importance != importance }
      
      # Do this for each committee, plus once for the total
      ("all".to_a + congress.committees).each do |committee|
        bills = Array.new(bills_importance)
        bills.reject! { |b| !b.committees.include?(committee) } if committee.class == Committee
        amended_bills = bills.reject { |b| b.amendments.size == 0 }
        @data = []
        
        # Do each representative
        representatives.each do |rep|
          
          # rep_data will contain all of the information in this row
          rep_data = []
          rep_data << "#{rep.last_name}, #{rep.first_name}"
          
          # Get this list of bills this rep sponsored, cosponsored, etc.
          rep_sponsored_bills = bills.reject { |b| !b.sponsors.include? rep }
          rep_sponsored_bills_unamended = rep_sponsored_bills.reject { |b| b.amendments.any? { |a| a.passed == true } }
          rep_cosponsored_bills = bills.reject { |b| !b.cosponsors.include? rep }
          rep_cosponsored_bills_unamended = rep_cosponsored_bills.reject { |b| b.amendments.any? { |a| a.passed == true } }
          
          # Put the data about each of those sets into rep_data
          rep_items(rep_data, rep_sponsored_bills)
          rep_items(rep_data, rep_sponsored_bills_unamended)
          rep_items(rep_data, rep_cosponsored_bills)
          rep_items(rep_data, rep_cosponsored_bills_unamended)
          
          # Repeat for the bills this rep amended
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
          
          # Calculate this rep's score and put it in rep_data
          score = 0.0
          amendment_bills_passed.each do |b|
            score += ( b.amendments.find_all { |a| a.sponsor_type == "Representative" and a.sponsor_id == rep.id and a.passed == true }.size.to_f / b.passed_amendments.size.to_f )
          end
          rep_data << score

          @data << rep_data
        end
        
        # Generate the csv-format string for this file
        data << [ render_to_string(:action => "reps", :layout => false), "#{congress.number.ordinalize}-reps-#{if importance==1 then "unimportant" elsif importance==2 then "regular" elsif importance==3 then "important" end}#{"-" + committee.name if committee.class == Committee}" ]        
      end
    end
  end
  
  # Do the same as the above, but organized by subcommmittee instead. Replicating the entire
  # method is almost certainly unneccesary; condense as future maintenance.
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
  
  # Same, but based on singly-referred vs. multiply-referred bills. Again, this can hopefully be condensed.
  def generate_repsreferrals(congress, data)
    @columns = reps_columns_args("Single Referral", "Multiple Referral")
    representatives = congress.representatives.sort {|x,y| x.last_name <=> y.last_name }
    all_bills = congress.bills
    1.upto(3) do |importance|
      bills_importance = all_bills.reject { |b| b.importance != importance }
      ("all".to_a + congress.committees).each do |committee|
        bills = Array.new(bills_importance)
        bills.reject! { |b| !b.committees.include?(committee) } if committee.class == Committee
        amended_bills = bills.reject { |b| b.multiple_referrals == 1 }
        @data = []
        representatives.each do |rep|
          rep_data = []
          rep_data << "#{rep.last_name}, #{rep.first_name}"
          rep_sponsored_bills = bills.reject { |b| !b.sponsors.include? rep }
          rep_sponsored_bills_unamended = rep_sponsored_bills.reject { |b| b.multiple_referrals == 0 }
          rep_cosponsored_bills = bills.reject { |b| !b.cosponsors.include? rep }
          rep_cosponsored_bills_unamended = rep_cosponsored_bills.reject { |b| b.multiple_referrals == 0 }
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
  
  # Finally, this does the same as the above, but sorted by the bill's issue. Same maintenance suggestion.
  def generate_repsissues(congress, data)
    @columns = reps_columns
    representatives = congress.representatives.sort {|x,y| x.last_name <=> y.last_name }
    all_bills = congress.bills
    1.upto(3) do |importance|
      bills_importance = all_bills.reject { |b| b.importance != importance }
      File.open("issues/names.txt").to_a.each do |issue|
        bills = Array.new(bills_importance)
        bills.reject! { |b| b.issue != (issue.chomp) }
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
        data << [ render_to_string(:action => "reps", :layout => false), "#{congress.number.ordinalize}-reps-#{if importance==1 then "unimportant" elsif importance==2 then "regular" elsif importance==3 then "important" end}#{"-" + issue.chomp}" ]        
      end
    end
  end
  
  # Writes the number of bills having particular properties to the specified array. Used
  # in the above functions.
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
  
  # Use the default parameters to the below.
  def reps_columns
    reps_columns_args("Unamended", "Amended")
  end
  
  # Generates the column titles for the reps report.
  def reps_columns_args (unamended, amended)
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
      "(Sponsored-#{unamended}) Introduced",
      "(Sponsored-#{unamended}) Referred To Committee",
      "(Sponsored-#{unamended}) Committee Hearing Held",
      "(Sponsored-#{unamended}) Committee markup held",
      "(Sponsored-#{unamended}) Reported by Committee",
      "(Sponsored-#{unamended}) Referred to Subcommittee",
      "(Sponsored-#{unamended}) Subcommittee hearing held",
      "(Sponsored-#{unamended}) Subcommittee markup held",
      "(Sponsored-#{unamended}) Forwarded from Subcommittee to Committee",
      "(Sponsored-#{unamended}) Action in committee",
      "(Sponsored-#{unamended}) Action beyond committee",
      "(Sponsored-#{unamended}) Placed on Union Calendar",
      "(Sponsored-#{unamended}) Placed on House Calendar",
      "(Sponsored-#{unamended}) Placed on Private Calendar",
      "(Sponsored-#{unamended}) Placed on Corrections Calendar",
      "(Sponsored-#{unamended}) Placed on Discharge Calendar",
      "(Sponsored-#{unamended}) Rules reported",
      "(Sponsored-#{unamended}) Rules passed",
      "(Sponsored-#{unamended}) Rules suspended",
      "(Sponsored-#{unamended}) Considered by unanimous consent",
      "(Sponsored-#{unamended}) Passed House",
      "(Sponsored-#{unamended}) Failed House",
      "(Sponsored-#{unamended}) Received in Senate",
      "(Sponsored-#{unamended}) Passed Senate",
      "(Sponsored-#{unamended}) Failed Senate",
      "(Sponsored-#{unamended}) Sent to conference committee",
      "(Sponsored-#{unamended}) Conference committee report issued",
      "(Sponsored-#{unamended}) Conference committee report passed House",
      "(Sponsored-#{unamended}) Conference committee report passed Senate",      
      "(Sponsored-#{unamended}) Presented to President",
      "(Sponsored-#{unamended}) Signed by President",
      "(Sponsored-#{unamended}) Vetoed by President",
      "(Sponsored-#{unamended}) House veto override successful",
      "(Sponsored-#{unamended}) Senate veto override successful",
      "(Sponsored-#{unamended}) House veto override failed",
      "(Sponsored-#{unamended}) Senate veto override failed",
      "(Sponsored-#{unamended}) Became law",
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
      "(Cosponsored-#{unamended}) Introduced",
      "(Cosponsored-#{unamended}) Referred To Committee",
      "(Cosponsored-#{unamended}) Committee Hearing Held",
      "(Cosponsored-#{unamended}) Committee markup held",
      "(Cosponsored-#{unamended}) Reported by Committee",
      "(Cosponsored-#{unamended}) Referred to Subcommittee",
      "(Cosponsored-#{unamended}) Subcommittee hearing held",
      "(Cosponsored-#{unamended}) Subcommittee markup held",
      "(Cosponsored-#{unamended}) Forwarded from Subcommittee to Committee",
      "(Cosponsored-#{unamended}) Action in committee",
      "(Cosponsored-#{unamended}) Action beyond committee",
      "(Cosponsored-#{unamended}) Placed on Union Calendar",
      "(Cosponsored-#{unamended}) Placed on House Calendar",
      "(Cosponsored-#{unamended}) Placed on Private Calendar",
      "(Cosponsored-#{unamended}) Placed on Corrections Calendar",
      "(Cosponsored-#{unamended}) Placed on Discharge Calendar",
      "(Cosponsored-#{unamended}) Rules reported",
      "(Cosponsored-#{unamended}) Rules passed",
      "(Cosponsored-#{unamended}) Rules suspended",
      "(Cosponsored-#{unamended}) Considered by unanimous consent",
      "(Cosponsored-#{unamended}) Passed House",
      "(Cosponsored-#{unamended}) Failed House",
      "(Cosponsored-#{unamended}) Received in Senate",
      "(Cosponsored-#{unamended}) Passed Senate",
      "(Cosponsored-#{unamended}) Failed Senate",
      "(Cosponsored-#{unamended}) Sent to conference committee",
      "(Cosponsored-#{unamended}) Conference committee report issued",
      "(Cosponsored-#{unamended}) Conference committee report passed House",
      "(Cosponsored-#{unamended}) Conference committee report passed Senate",
      "(Cosponsored-#{unamended}) Presented to President",
      "(Cosponsored-#{unamended}) Signed by President",
      "(Cosponsored-#{unamended}) Vetoed by President",
      "(Cosponsored-#{unamended}) House veto override successful",
      "(Cosponsored-#{unamended}) Senate veto override successful",
      "(Cosponsored-#{unamended}) House veto override failed",
      "(Cosponsored-#{unamended}) Senate veto override failed",
      "(Cosponsored-#{unamended}) Became law",
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
