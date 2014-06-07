class CreateEvents < ActiveRecord::Migration
  def self.up
    create_table :events do |t|
      t.column :date, :date
      t.column :title, :text
      t.column :bill_id, :integer
    end
  end

  def self.down
    drop_table :events
  end
end
