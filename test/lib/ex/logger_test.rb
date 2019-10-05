require 'test_helper'

class ExLoggerTest < ActiveSupport::TestCase
  test "info exception with message" do
  	begin
  		raise "what"
  	rescue => ex
	  	Ex::Logger.info(ex, "what is this")
  	end
  end

  test "info exception without msg" do
  	begin
  		raise "what"
  	rescue => ex
	  	Ex::Logger.info(ex)
  	end
  end

  test "error exception without msg" do
  	begin
  		raise "what"
  	rescue => ex
	  	Ex::Logger.error(ex)
  	end
  end

end
