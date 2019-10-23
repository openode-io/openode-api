# frozen_string_literal: true

require 'test_helper'

class ExLoggerTest < ActiveSupport::TestCase
  test 'info exception with message' do
    raise 'what'
  rescue StandardError => e
    Ex::Logger.info(e, 'what is this')
  end

  test 'info exception without msg' do
    raise 'what'
  rescue StandardError => e
    Ex::Logger.info(e)
  end

  test 'error exception without msg' do
    raise 'what'
  rescue StandardError => e
    Ex::Logger.error(e)
  end
end
