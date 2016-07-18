class CreateSenateBills < ActiveRecord::Migration
  def self.up
    create_table "senate_bills" do |t|
      t.integer "id"
      t.integer "name"
      t.text "title"
      t.boolean "passed"
      t.string "issue"
      t.integer "importance"
      t.integer "congress_id"
      t.integer "BILL"
      t.integer "AIC"
      t.integer "ABC"
      t.integer "PASS"
      t.integer "LAW"
    end

    add_index "senate_bills", ["congress_id", "importance"], :name => "index_sen_bills_on_cid_and_importance"
    add_index "senate_bills", ["importance"], :name => "index_bills_on_importance"
  end

  def self.down
    drop_table :senate_bills
  end
end
