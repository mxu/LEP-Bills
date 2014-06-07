# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  require 'open-uri'
  require 'net/http'
  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_bills_session_id'
  
  # Use to define multi-dimensional arrays
  def mda(width,height)
    a = Array.new(width)
    a.map! { Array.new(height) }
    return a
  end
  
end
