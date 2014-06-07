class AddRulesConferences < ActiveRecord::Migration
  def self.up
    add_column :bills, :rule_reported_on, :date
    add_column :bills, :rule_passed_on, :date
    add_column :bills, :sent_to_conference_committee_on, :date
    add_column :bills, :conference_committee_report_issued_on, :date
    add_column :bills, :conference_committee_passed_house_on, :date
    add_column :bills, :conference_committee_passed_senate_on, :date
  end

  def self.down
    remove_column :bills, :rule_reported_on
    remove_column :bills, :rule_passed_on
    remove_column :bills, :sent_to_conference_committee_on
    remove_column :bills, :conference_committee_report_issued_on
    remove_column :bills, :conference_committee_passed_house_on
    remove_column :bills, :conference_committee_passed_senate_on
  end
end
