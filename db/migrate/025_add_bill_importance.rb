class AddBillImportance < ActiveRecord::Migration
  def self.up
    add_column :bills, :importance, :integer
  end

  def self.down
    remove_column :bills, :importance
  end
end
