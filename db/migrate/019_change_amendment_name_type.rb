class ChangeAmendmentNameType < ActiveRecord::Migration
  def self.up
    change_column :amendments, :name, :integer
  end

  def self.down
    change_column :amendments, :name, :string
  end
end
