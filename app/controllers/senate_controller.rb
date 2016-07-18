class SenateController < ApplicationController
  layout 'default'

  def index
    list
    render :action => "list"
  end

  def list
    @congresses = Congress.find(:all, :order => :number)
  end

  def fetch
    puts "fetch senate data"
  end

end
