
require 'rest-client'

module Api
  class Paypal
    # Minimal paypal api sdk for https://developer.paypal.com/docs/api/overview

    def initialize
      @client_id = ENV.fetch("PAYPAL_API_CLIENT_ID")
      @secret = ENV.fetch("PAYPAL_API_SECRET_KEY")
      @host = ENV.fetch("PAYPAL_API_URL", "https://api-m.paypal.com")
    end

    def refresh_access_token
      encoded = Base64.encode64("#{@client_id}:#{@secret}".force_encoding('UTF-8')).gsub!(/\n/, "")

      result = RestClient::Request.execute(
        method: :post,
        url: "#{@host}/v1/oauth2/token",
        headers: {
          "Content-Type" => "application/x-www-form-urlencoded",
          "Authorization" => "Basic #{encoded}"
        },
        payload: { "grant_type" => "client_credentials" }
      )

      @access_token = JSON.parse(result).dig('access_token')
    end

    def execute(method, path, payload = nil)
      result = RestClient::Request.execute(
        method: method,
        url: "#{@host}#{path}",
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{@access_token}"
        },
        payload: payload
      )

      JSON.parse(result) rescue {}
    end
  end
end
