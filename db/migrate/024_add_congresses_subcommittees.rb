class AddCongressesSubcommittees < ActiveRecord::Migration
  def self.up
    create_table :congresses_subcommittees, :id => false do |t|
      t.column :congress_id, :integer
      t.column :subcommittee_id, :integer
    end
  end

  def self.down
    drop_table :congresses_subcommittees, :id => false
  end
end
