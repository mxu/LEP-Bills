class CreateAmendments < ActiveRecord::Migration
  def self.up
    create_table :amendments do |t|
      t.column :name, :string
      t.column :number, :string
      t.column :description, :text
      t.column :purpose, :text
      t.column :offered_on, :date
      t.column :bill_id, :integer
      t.column :sponsor_id, :integer
      t.column :sponsor_type, :string
    end
  end

  def self.down
    drop_table :amendments
  end
end
