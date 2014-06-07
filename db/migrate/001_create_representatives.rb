class CreateRepresentatives < ActiveRecord::Migration
  def self.up
    create_table :representatives do |t|
      t.column :first_name, :string
      t.column :last_name, :string
      t.column :middle_name, :string
      t.column :nickname, :string
      t.column :suffix, :string
      t.column :district, :integer
      t.column :state, :string
    end
  end

  def self.down
    drop_table :representatives
  end
end
