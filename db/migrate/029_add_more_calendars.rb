class AddMoreCalendars < ActiveRecord::Migration
  def self.up
    add_column :bills, :placed_on_consent_calendar_on, :date
    add_column :bills, :placed_on_senate_legislative_calendar_on, :date
  end

  def self.down
    remove_column :bills, :placed_on_consent_calendar_on
    remove_column :bills, :placed_on_senate_legislative_calendar_on
  end
end
