class CreateSubcommittees < ActiveRecord::Migration
  def self.up
    create_table :subcommittees do |t|
      t.column :name, :string
    end
  end

  def self.down
    drop_table :subcommittees
  end
end
