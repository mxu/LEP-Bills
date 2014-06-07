class AddMoreToBills < ActiveRecord::Migration
  def self.up
    add_column :bills, :failed_house_on, :date
    add_column :bills, :failed_senate_on, :date
    add_column :bills, :house_veto_override_on, :date
    add_column :bills, :senate_veto_override_on, :date
    add_column :bills, :forwarded_from_subcommittee_to_committee_on, :date
    add_column :bills, :reported_by_committee_on, :date
  end

  def self.down
    remove_column :bills, :failed_house_on
    remove_column :bills, :failed_senate_on
    remove_column :bills, :house_veto_override_on
    remove_column :bills, :senate_veto_override_on
    remove_column :bills, :forwarded_from_subcommittee_to_committee_on
    remove_column :bills, :reported_by_committee_on
  end
end
