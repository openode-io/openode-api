Apipie.configure do |config|
  config.app_name                = "Openode API"
  config.api_base_url            = "/"
  config.doc_base_url            = "/documentation"

  config.translate = false

  # where is your API defined?
  config.api_controllers_matcher = Rails.root.join("app/controllers/**/*.rb")
end

module Apipie
  def self.app_info(_version = nil, _lang = nil)
    'Official opeNode API documentation. <br />
    <p>Note that our <a href="https://www.openode.io/openode-cli">CLI</a> uses
    this API in a convenient manner.</p>

    <p><b>The API token must be provided using the following
    HTTP header: x-auth-token: YOUR_TOKEN.</b></p>

    <hr />

    <p>Requests through the API are rate limited per user token.</p>
    <ul>
      <li>' + ApiRateLimit::PER_MINUTE_RATE_LIMIT.to_s + ' Requests per minute</li>
    </ul>
    <p>Some headers are set on responses:</p>
    <ul>
      <li><strong>' + ApiRateLimit::HEADER_NAME_REMAINING + '</strong></li>
      <li><strong>' + ApiRateLimit::HEADER_NAME_LIMIT + '</strong></li>
      <li><strong>' + ApiRateLimit::HEADER_NAME_REMAINING + '</strong></li>
    </ul>
    '
  end
end
