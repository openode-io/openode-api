require 'rest-client'

module Api
  class Openode
    attr_reader :token

    def initialize(args = {})
      @token = args[:token]
    end

    def execute(method, path = "/", args = {})
      headers = {
        "x-auth-token": @token,
        "params": args[:params] || {}
      }

      url = "#{Rails.configuration.API_URL}#{path}"

      JSON.parse(RestClient::Request.execute(method: method,
                                             url: url,
                                             timeout: 120,
                                             payload: args[:payload],
                                             headers: headers))
    end
  end
end
