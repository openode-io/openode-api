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

  test 'happy path - detected missing git' do
    log = "hello world \n" \
          " spawn git ENOENT---\n" \
          "asdf"

    result = DeploymentMethod::Util::OutputDiagnostic.analyze("build_image", log)

    assert_includes result, "Package git is missing"
    assert_includes result, "A package (git) seems"
  end

  test 'happy path - regex should not be multiline' do
    log = "hello spawn world \n" \
          "  git ---\n" \
          "as ENOENT df"

    result = DeploymentMethod::Util::OutputDiagnostic.analyze("build_image", log)

    assert_equal result, ""
  end
end
