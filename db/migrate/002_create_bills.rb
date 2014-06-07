class CreateBills < ActiveRecord::Migration
  def self.up
    create_table :bills do |t|
      t.column :name, :string
      t.column :title, :text
      t.column :passed, :boolean
      t.column :representative_id, :integer
      t.column :introduced_on, :date
      t.column :referred_to_committee_on, :date
      t.column :committee_hearing_held_on, :date
      t.column :committee_markup_held_on, :date
      t.column :referred_to_subcommittee_on, :date
      t.column :subcommittee_hearing_held_on, :date
      t.column :subcommittee_markup_held_on, :date
      t.column :presented_to_president_on, :date
      t.column :vetoed_by_president_on, :date
      t.column :signed_by_president_on, :date
    end
  end

  def self.down
    drop_table :bills
  end
end
