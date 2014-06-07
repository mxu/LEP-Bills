#This class simply gathers the data on representatives and displays it.

class RepresentativesController < ApplicationController
  layout 'default'
  auto_complete_for :representative, :last_name
  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

  def list
    @representative_pages, @representatives = paginate :representatives, :per_page => 250, :order => 'last_name, first_name'
  end

  def show
    @representative = Representative.find(params[:id])
  end
  
  def search
    @searchphrase = params[:representative][:last_name]
   
    @representative_pages, @representatives = paginate :representatives, :per_page => 25, :order => 'last_name, first_name', :conditions => [ "LOWER(last_name) LIKE ?", "%#{@searchphrase}%"]
    if @representatives.size == 0 then
      flash[:notice] = "No records found matching '#{@searchphrase}'"
      redirect_to :action => "list"
    else
      render :action => "list"
    end
  end

end
