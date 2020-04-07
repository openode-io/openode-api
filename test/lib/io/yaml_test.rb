
require 'test_helper'

class IoYamlTest < ActiveSupport::TestCase
  test 'valid? - happy path' do
    y = IO.read('test/fixtures/collaborators.yml')

    assert_equal Io::Yaml.valid?(y), true
  end

  test 'valid? - invalid' do
    y = "\n\n   a: \"as\"df\""

    assert_equal Io::Yaml.valid?(y), false
  end
end
