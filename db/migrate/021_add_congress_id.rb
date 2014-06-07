class AddCongressId < ActiveRecord::Migration
  def self.up
    add_column :bills, :congress_id, :integer
    add_column :amendments, :congress_id, :integer
  end

  def self.down
    remove_column :bills, :congress_id
    remove_column :amendments, :congress_id
  end
end
