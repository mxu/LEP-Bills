class AddBillsCommittees < ActiveRecord::Migration
  def self.up
    create_table :bills_committees, :id => false do |t|
      t.column :bill_id, :integer
      t.column :committee_id, :integer
    end
  end

  def self.down
    drop_table :bills_committees
  end
end
