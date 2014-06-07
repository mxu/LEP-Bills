class AddCongressesRepresentatives < ActiveRecord::Migration
  def self.up
    create_table :congresses_representatives, :id => false do |t|
      t.column :congress_id, :integer
      t.column :representative_id, :integer
    end
  end

  def self.down
    drop_table :congresses_representatives
  end
end
