require 'rest-client'

module Payment
  class Paypal
    PAYPAL_VERIFICATION_URL = "https://ipnpb.paypal.com/cgi-bin/webscr?"
    PAYPAL_VERIFICATION_VARIABLE = "cmd"
    PAYPAL_VERIFICATION_VALUE = "_notify-validate"

    def self.parse(input_obj)
      cleaned_obj = JSON.parse(input_obj.to_json.gsub(/[\u0080-\u00ff]/, ''))

      {
        'content' => cleaned_obj,
        'amount' => cleaned_obj['mc_gross'].to_f,
        'user_id' => cleaned_obj['custom'].to_i,
        'payment_status' => cleaned_obj['payment_status']
      }
    end

    def self.completed?(parsed_order)
      parsed_order && parsed_order['payment_status'] == 'Completed'
    end

    # call IPN paypal to verify
    def self.prepare_validate_transaction_url(input_obj)
      vars = { PAYPAL_VERIFICATION_VARIABLE => PAYPAL_VERIFICATION_VALUE }.merge(input_obj)
      params_s = vars.keys.map { |k| "#{k}=#{vars[k]}" }.join("&")

      "#{PAYPAL_VERIFICATION_URL}#{params_s}"
    end

    def self.transaction_valid?(input_obj)
      url = Paypal.prepare_validate_transaction_url(input_obj)

      begin
        Rails.logger.info("Paypal IPN verification -> #{url}")
        result = RestClient::Request.execute(method: :get, url: url)

        result.include?('VERIFIED')
      rescue StandardError => e
        Rails.logger.error("Paypal IPN failed - #{e}")
        false
      end
    end
  end
end
