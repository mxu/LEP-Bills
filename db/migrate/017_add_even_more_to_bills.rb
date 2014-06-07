class AddEvenMoreToBills < ActiveRecord::Migration
  def self.up
    add_column :bills, :rules_suspended_on, :date
    add_column :bills, :considered_by_unanimous_consent_on, :date
    add_column :bills, :received_in_senate_on, :date
    add_column :bills, :house_veto_override_failed_on, :date
    add_column :bills, :senate_veto_override_failed_on, :date
  end

  def self.down
    remove_column :bills, :rules_suspended_on
    remove_column :bills, :considered_by_unanimous_consent_on
    remove_column :bills, :received_in_senate_on
    remove_column :bills, :house_veto_override_failed_on
    remove_column :bills, :senate_veto_override_failed_on
  end
end
