class AddCommitteesCongresses < ActiveRecord::Migration
  def self.up
    create_table :committees_congresses, :id => false do |t|
      t.column :committee_id, :integer
      t.column :congress_id, :integer
    end
  end

  def self.down
    drop_table :committees_congresses, :id => false
  end
end
