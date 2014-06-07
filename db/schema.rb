# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of ActiveRecord to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 34) do

  create_table "amendments", :force => true do |t|
    t.integer "name"
    t.string  "number"
    t.text    "description"
    t.text    "purpose"
    t.date    "offered_on"
    t.integer "bill_id"
    t.integer "sponsor_id"
    t.string  "sponsor_type"
    t.boolean "passed"
    t.integer "congress_id"
  end

  add_index "amendments", ["bill_id"], :name => "index_amendments_on_bill_id"
  add_index "amendments", ["congress_id"], :name => "index_amendments_on_congress_id"

  create_table "bills", :force => true do |t|
    t.integer "name"
    t.text    "title"
    t.boolean "passed"
    t.date    "introduced_on"
    t.date    "referred_to_committee_on"
    t.date    "committee_hearing_held_on"
    t.date    "committee_markup_held_on"
    t.date    "referred_to_subcommittee_on"
    t.date    "subcommittee_hearing_held_on"
    t.date    "subcommittee_markup_held_on"
    t.date    "presented_to_president_on"
    t.date    "vetoed_by_president_on"
    t.date    "signed_by_president_on"
    t.date    "placed_on_union_calendar_on"
    t.date    "placed_on_house_calendar_on"
    t.date    "placed_on_private_calendar_on"
    t.date    "placed_on_discharge_calendar_on"
    t.date    "placed_on_corrections_calendar_on"
    t.date    "passed_house_on"
    t.date    "passed_senate_on"
    t.date    "rule_reported_on"
    t.date    "rule_passed_on"
    t.date    "sent_to_conference_committee_on"
    t.date    "conference_committee_report_issued_on"
    t.date    "conference_committee_passed_house_on"
    t.date    "conference_committee_passed_senate_on"
    t.date    "failed_house_on"
    t.date    "failed_senate_on"
    t.date    "house_veto_override_on"
    t.date    "senate_veto_override_on"
    t.date    "forwarded_from_subcommittee_to_committee_on"
    t.date    "reported_by_committee_on"
    t.date    "rules_suspended_on"
    t.date    "considered_by_unanimous_consent_on"
    t.date    "received_in_senate_on"
    t.date    "house_veto_override_failed_on"
    t.date    "senate_veto_override_failed_on"
    t.integer "congress_id"
    t.integer "importance"
    t.date    "placed_on_consent_calendar_on"
    t.date    "placed_on_senate_legislative_calendar_on"
    t.date    "became_law_on"
    t.string  "issue"
  end

  add_index "bills", ["congress_id", "importance"], :name => "index_bills_on_congress_id_and_importance"
  add_index "bills", ["importance"], :name => "index_bills_on_importance"

  create_table "bills_committees", :id => false, :force => true do |t|
    t.integer "bill_id"
    t.integer "committee_id"
  end

  add_index "bills_committees", ["bill_id"], :name => "index_bills_committees_on_bill_id"
  add_index "bills_committees", ["committee_id"], :name => "index_bills_committees_on_committee_id"

  create_table "bills_cosponsors", :id => false, :force => true do |t|
    t.integer "bill_id"
    t.integer "representative_id"
  end

  add_index "bills_cosponsors", ["bill_id"], :name => "index_bills_cosponsors_on_bill_id"
  add_index "bills_cosponsors", ["representative_id"], :name => "index_bills_cosponsors_on_representative_id"

  create_table "bills_sponsors", :id => false, :force => true do |t|
    t.integer "bill_id"
    t.integer "representative_id"
  end

  add_index "bills_sponsors", ["bill_id"], :name => "index_bills_sponsors_on_bill_id"
  add_index "bills_sponsors", ["representative_id"], :name => "index_bills_sponsors_on_representative_id"

  create_table "bills_subcommittees", :id => false, :force => true do |t|
    t.integer "bill_id"
    t.integer "subcommittee_id"
  end

  add_index "bills_subcommittees", ["bill_id"], :name => "index_bills_subcommittees_on_bill_id"
  add_index "bills_subcommittees", ["subcommittee_id"], :name => "index_bills_subcommittees_on_subcommittee_id"

  create_table "committees", :force => true do |t|
    t.string "name"
  end

  create_table "committees_congresses", :id => false, :force => true do |t|
    t.integer "committee_id"
    t.integer "congress_id"
  end

  create_table "congresses", :force => true do |t|
    t.integer "number"
  end

  create_table "congresses_representatives", :id => false, :force => true do |t|
    t.integer "congress_id"
    t.integer "representative_id"
  end

  create_table "congresses_subcommittees", :id => false, :force => true do |t|
    t.integer "congress_id"
    t.integer "subcommittee_id"
  end

  create_table "cosponsorships", :force => true do |t|
    t.integer "bill_id"
    t.integer "representative_id"
    t.date    "date"
  end

  create_table "events", :force => true do |t|
    t.date    "date"
    t.text    "title"
    t.integer "bill_id"
  end

  add_index "events", ["bill_id"], :name => "index_events_on_bill_id"

  create_table "ranking_phrases", :force => true do |t|
    t.string   "phrase"
    t.boolean  "exception"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "regex"
  end

  create_table "representatives", :force => true do |t|
    t.string  "first_name"
    t.string  "last_name"
    t.string  "middle_name"
    t.string  "nickname"
    t.string  "suffix"
    t.integer "district"
    t.string  "state"
  end

  add_index "representatives", ["last_name", "first_name"], :name => "index_representatives_on_last_name_and_first_name", :unique => true

  create_table "roll_calls", :force => true do |t|
    t.integer  "roll_number"
    t.integer  "year"
    t.string   "vote_question"
    t.datetime "date"
    t.integer  "event_id"
  end

  create_table "subcommittees", :force => true do |t|
    t.string "name"
  end

  create_table "votes", :force => true do |t|
    t.integer "roll_call_id"
    t.integer "representative_id"
    t.string  "vote"
  end

end
