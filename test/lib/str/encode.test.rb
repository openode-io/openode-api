# frozen_string_literal: true

require 'test_helper'

class StrEncodeTest < ActiveSupport::TestCase
  def setup; end

  test 'simple str encode' do
    assert_equal(Str::Encode.strip_invalid_chars(
                   "\x80\xA6,b8dc2ace0c265d\xE2\x80\xA632bfe26"
                 ),
                 ',b8dc2ace0c265d…32bfe26')
  end

  test 'simple obj' do
    obj = {
      what: "\x80\xA6,b8dc2",
      is: "\x80\xA6,b8dc2"
    }

    result = Str::Encode.strip_invalid_chars(obj)

    assert_equal result[:what], ',b8dc2'
    assert_equal result[:is], ',b8dc2'
  end

  test 'simple obj - strip invalid chars' do
    obj = {
      what: "titi",
      is: "toto",
      tt: "hey\xD0\xBF\xD0\xB2\xD0\xBF"
    }

    result = Str::Encode.strip_invalid_chars(obj, encoding: 'ASCII')

    assert_equal result[:what], 'titi'
    assert_equal result[:is], 'toto'
    assert_equal result[:tt], 'hey'
  end
end
