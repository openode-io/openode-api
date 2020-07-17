require 'rest-client'

module Payment
  class Paypal
    PAYPAL_VERIFICATION_URL = "https://ipnpb.paypal.com/cgi-bin"

    def self.strip_input_obj(input_obj)
      input_obj.each do |k, v|
        input_obj[k] = if v&.class == String
                         v.dup.force_encoding('ISO-8859-1').encode('UTF-8')
                       else
                         v
          end
      end
    end

    def self.parse(input_obj)
      cleaned_obj = JSON.parse(
        strip_input_obj(input_obj).to_json.gsub(/[\u0080-\u00ff]/, '')
      )

      {
        'content' => cleaned_obj,
        'amount' =>
          (cleaned_obj['mc_gross'].to_f - (cleaned_obj['tax']&.to_f || 0)).round(2),
        'user_id' => cleaned_obj['custom'].to_i,
        'payment_status' => cleaned_obj['payment_status']
      }
    end

    def self.completed?(parsed_order)
      parsed_order && parsed_order['payment_status'] == 'Completed'
    end

    def self.validate_ipn_notification(raw)
      live = PAYPAL_VERIFICATION_URL

      uri = URI.parse(live + '/webscr?cmd=_notify-validate')

      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 60
      http.read_timeout = 60
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.use_ssl = true
      http.post(uri.request_uri, raw,
                'Content-Length' => raw.size.to_s,
                'User-Agent' => "My custom user agent").body
    end

    def self.transaction_valid?(raw)
      Rails.logger.info("Paypal transaction input -> #{raw}")

      result_ipn = Paypal.validate_ipn_notification(raw) rescue 'error'
      Rails.logger.info("Paypal transaction IPN result: #{result_ipn}")

      result_ipn == 'VERIFIED'
    end
  end
end
