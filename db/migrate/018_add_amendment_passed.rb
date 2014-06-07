class AddAmendmentPassed < ActiveRecord::Migration
  def self.up
    add_column :amendments, :passed, :boolean
  end

  def self.down
    remove_column :amendments, :passed
  end
end
