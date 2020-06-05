require 'test_helper'

class OutputDiagnosticTest < ActiveSupport::TestCase
  test 'happy path - detected build image issue' do
    log = "hello world \n" \
          "You need to install the latest version of Python---"

    result = DeploymentMethod::Util::OutputDiagnostic.analyze("build_image", log)

    assert_includes result, "add the following instruction"
  end

  test 'happy path - nothing detected' do
    log = "hello world \n" \
          ""

    result = DeploymentMethod::Util::OutputDiagnostic.analyze("build_image", log)

    assert_equal result, ""
  end

  test 'wrong element to analyze' do
    log = "hello world \n"

    result = DeploymentMethod::Util::OutputDiagnostic.analyze("whatiswronghere", log)

    assert_equal result, ""
  end
end
