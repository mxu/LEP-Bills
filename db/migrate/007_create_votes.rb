class CreateVotes < ActiveRecord::Migration
  def self.up
    create_table :votes do |t|
      t.column :roll_call_id, :integer
      t.column :representative_id, :integer
      t.column :vote, :string
    end
  end

  def self.down
    drop_table :votes
  end
end
