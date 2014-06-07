class AddIssues < ActiveRecord::Migration
  def self.up
    add_column :bills, :issue, :string
  end

  def self.down
    remove_column :bills, :issue, :string
  end
end
