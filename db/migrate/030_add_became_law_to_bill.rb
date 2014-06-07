class AddBecameLawToBill < ActiveRecord::Migration
  def self.up
    add_column :bills, :became_law_on, :date
  end

  def self.down
    remove_column :bills, :became_law_on
  end
end
