class AddCalendars < ActiveRecord::Migration
  def self.up
    add_column :bills, :placed_on_union_calendar_on, :date
    add_column :bills, :placed_on_house_calendar_on, :date
    add_column :bills, :placed_on_private_calendar_on, :date
    add_column :bills, :placed_on_discharge_calendar_on, :date
    add_column :bills, :placed_on_corrections_calendar_on, :date
  end

  def self.down
    remove_column :bills, :placed_on_union_calendar_on
    remove_column :bills, :placed_on_house_calendar_on
    remove_column :bills, :placed_on_private_calendar_on
    remove_column :bills, :placed_on_discharge_calendar_on
    remove_column :bills, :placed_on_corrections_calendar_on
  end
end
