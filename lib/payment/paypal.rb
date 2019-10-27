module Payment
  class Paypal
    def self.parse(input_obj)
      cleaned_obj = JSON.parse(input_obj.to_json.gsub(/[\u0080-\u00ff]/, ''))

      {
        'content' => cleaned_obj,
        'amount' => cleaned_obj['mc_gross'].to_f,
        'user_id' => cleaned_obj['custom'].to_i,
        'payment_status' => cleaned_obj['payment_status']
      }
    end
  end
end
