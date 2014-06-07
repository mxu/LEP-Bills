class ExtendRankingPhrase < ActiveRecord::Migration
  def self.up
		add_column :ranking_phrases, :regex, :boolean
  end

  def self.down
		remove_column :ranking_phrases, :regex, :boolean
  end
end
