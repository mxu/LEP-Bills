class AddBillsSubcommittees < ActiveRecord::Migration
  def self.up
    create_table :bills_subcommittees, :id => false do |t|
      t.column :bill_id, :integer
      t.column :subcommittee_id, :integer
    end
  end

  def self.down
    drop_table :bills_subcommittees
  end
end
