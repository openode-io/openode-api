require 'test_helper'

class ExRetryTest < ActiveSupport::TestCase
  test 'n_times when successful' do
    arr = []

    Ex::Retry.n_times(nb_trials: 6) do |i|
      arr << "trying...#{i}"
    end

    assert_equal arr, ["trying...0"]
  end

  test 'n_times all failing' do
    Ex::Retry.n_times(nb_trials: 6) do |i|
      raise "failing at #{i}"
    end

    assert false
  rescue StandardError => e
    assert_equal e.to_s, "failing at 5"
  end

  test 'n_times should return the proper result' do
    my_result = Ex::Retry.n_times(nb_trials: 3) do |_i|
      {
        result: 'is'
      }
    end

    assert_equal my_result[:result], 'is'
  end
end
