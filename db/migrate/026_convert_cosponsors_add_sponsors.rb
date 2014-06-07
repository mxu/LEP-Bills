class ConvertCosponsorsAddSponsors < ActiveRecord::Migration
  def self.up
    drop_table :cosponsorships
    create_table :bills_sponsors, :id => false do |t|
      t.column :bill_id, :integer
      t.column :representative_id, :integer
    end
    create_table :bills_cosponsors, :id => false do |t|
      t.column :bill_id, :integer
      t.column :representative_id, :integer
    end
    remove_column :bills, :representative_id
  end

  def self.down
    create_table :cosponsorships do |t|
        t.column :bill_id, :integer
        t.column :representative_id, :integer
        t.column :date, :date
    end
    add_column :bills, :representative_id, :integer
    drop_table :bills_sponsors
    drop_table :bills_cosponsors
  end
end
