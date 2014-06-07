class AddPassed < ActiveRecord::Migration
  def self.up
    add_column :bills, :passed_house_on, :date
    add_column :bills, :passed_senate_on, :date
  end

  def self.down
    remove_column :bills, :passed_house_on
    remove_column :bills, :passed_senate_on
  end
end
