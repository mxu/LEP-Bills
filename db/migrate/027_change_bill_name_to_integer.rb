class ChangeBillNameToInteger < ActiveRecord::Migration
  def self.up
    change_column :bills, :name, :integer
  end

  def self.down
    change_column :bills, :name, :string
  end
end
