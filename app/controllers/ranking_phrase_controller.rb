class RankingPhraseController < ApplicationController
	layout 'default'
	def index
		redirect_to :action=>'show'
	end

  # This page has no logic
  def show
  end
	
  # Creates a new ranking phrase based on the parameters in the form
	def new
		r = RankingPhrase.new
		r.phrase = params[:phrase]
		r.exception = params[:rank][:exception]=="1"
		r.regex = params[:rank][:regex]=="1"
		r.save
		flash[:notice] = "Phrase added successfully"
		redirect_to :action=>'show'
	end
	
  # Deletes the ranking phrase chosen from the display
	def remove
		RankingPhrase.find(params[:id]).destroy
		flash[:notice] = "Phrase removed successfully"
		redirect_to :action=>'show'
	end
	
end
