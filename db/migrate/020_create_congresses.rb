class CreateCongresses < ActiveRecord::Migration
  def self.up
    create_table :congresses do |t|
      t.column :number, :integer
    end
  end

  def self.down
    drop_table :congresses
  end
end
