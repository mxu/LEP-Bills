class RetrofitCosponsorship < ActiveRecord::Migration
  def self.up
    create_table :cosponsorships do |t|
      t.column :bill_id, :integer
      t.column :representative_id, :integer
      t.column :date, :date
    end
  end

  def self.down
    drop_table :cosponsorships
  end
end
