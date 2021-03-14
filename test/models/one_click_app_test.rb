require "test_helper"

class OneClickAppTest < ActiveSupport::TestCase
  test "create" do
    app = OneClickApp.create!(name: "hello", config: { "what" => "test" })

    app.reload

    assert app.name == "hello"
    assert app.config['what'] == "test"
  end
end
