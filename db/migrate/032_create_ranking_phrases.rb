class CreateRankingPhrases < ActiveRecord::Migration
  def self.up
    create_table :ranking_phrases do |t|
			t.column :phrase, :string
			t.column :exception, :boolean
      t.timestamps
    end
  end

  def self.down
    drop_table :ranking_phrases
  end
end
