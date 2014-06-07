class AddIndex < ActiveRecord::Migration
  def self.up
    add_index :events, :bill_id
    add_index :bills, [ :congress_id, :importance ]
    add_index :bills, :importance
    add_index :amendments, :bill_id    
    add_index :amendments, :congress_id
    add_index :bills_committees, :bill_id
    add_index :bills_committees, :committee_id
    add_index :bills_subcommittees, :bill_id
    add_index :bills_subcommittees, :subcommittee_id
    add_index :bills_sponsors, :bill_id
    add_index :bills_sponsors, :representative_id
    add_index :bills_cosponsors, :bill_id
    add_index :bills_cosponsors, :representative_id
    add_index :representatives, [ :last_name, :first_name ], :unique => true
  end

  def self.down
    remove_index :events, :bill_id
    remove_index :bills, [ :congress_id, :importance ]
    remove_index :bills, :importance
    remove_index :amendments, :bill_id    
    remove_index :amendments, :congress_id
    remove_index :bills_committees, :bill_id
    remove_index :bills_committees, :committee_id
    remove_index :bills_subcommittees, :bill_id
    remove_index :bills_subcommittees, :subcommittee_id
    remove_index :bills_sponsors, :bill_id
    remove_index :bills_sponsors, :representative_id
    remove_index :bills_cosponsors, :bill_id
    remove_index :bills_cosponsors, :representative_id
    remove_index :representatives, [ :last_name, :first_name ]
  end
end
