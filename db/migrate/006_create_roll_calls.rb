class CreateRollCalls < ActiveRecord::Migration
  def self.up
    create_table :roll_calls do |t|
      t.column :roll_number, :integer
      t.column :year, :integer
      t.column :vote_question, :string
      t.column :date, :datetime
      t.column :event_id, :integer
    end
  end

  def self.down
    drop_table :roll_calls
  end
end
