
require 'rest-client'

module Api
  class Paypal
    attr_reader :client_id
    attr_reader :secret

    def initialize()
      @client_id = ENV.fetch("PAYPAL_API_CLIENT_ID")
      @secret = ENV.fetch("PAYPAL_API_SECRET_KEY")
      @host = ENV.fetch("PAYPAL_API_URL", "https://api-m.paypal.com")
    end

    def get_access_token
      puts "clien id #{@client_id}:#{@secret}--"
      encoded = Base64::encode64("#{@client_id}:#{@secret}".force_encoding('UTF-8')).gsub!(/\n/, "")
      puts "encoded #{encoded}"
      result = RestClient::Request.execute(
        method: :post,
        url: "#{@host}/v1/oauth2/token",
        #user: @client_id, password: @secret,
        headers: {
          "Content-Type" => "application/x-www-form-urlencoded",
          "Authorization" => "Basic #{encoded}"
        },
        payload: { "grant_type" => "client_credentials"}
      )

      puts "ress #{result}"
    end
  end
end
