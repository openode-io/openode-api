
module ActionDispatch
  class Request
    class Utils # :nodoc:
      def self.check_param_encoding(params)
        # skipping this, to avoid failing with Invalid encoding for parameter
        # due to Catch invalid UTF-8 parameters for POST requests and respond with BadRequest.
        # introduced in rails 6.1.0
      end
    end
  end
end
