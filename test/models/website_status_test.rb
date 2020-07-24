require 'test_helper'

class WebsiteStatusTest < ActiveSupport::TestCase
  test 'create' do
    w = default_website

    web_status = WebsiteStatus.log(
      w,
      status: {
        what: 0,
        is: 1
      }
    )

    assert_equal web_status.website.id, w.id
    assert_equal web_status.obj['status']['what'], 0

    statuses = w.reload.statuses

    assert_equal statuses.length, 1
    assert_equal statuses.first.obj['status']['what'], 0
  end

  test 'simplified_container_statuses - multi pods' do
    w = default_website

    st = WebsiteStatus.log(
      w,
      [
        {
          label_app: 'www',
          status: {
            containerStatuses: [
              {
                what: 0,
                is: 1
              }
            ]
          }
        },
        {
          label_app: 'www',
          status: {
            containerStatuses: [
              {
                what: 2,
                is: 1
              }
            ]
          }
        }
      ]
    )

    statuses = st.simplified_container_statuses

    assert_equal statuses.length, 2
    assert_equal statuses.first['what'], 0
    assert_equal statuses.last['what'], 2
  end

  test 'statuses_containing_terminated_reason - with oom' do
    w = default_website

    web_status = WebsiteStatus.log(
      w,
      [
        {
          status: {
            containerStatuses: [
              {
                what: 0,
                is: 1,
                lastState: {
                  terminated: {
                    reason: 'oomkilled'
                  }
                }
              }
            ]
          }
        }
      ]
    )

    statuses = web_status.statuses_containing_terminated_reason('oomkilled')

    assert_equal statuses.length, 1
    assert_equal statuses.first.dig('lastState', 'terminated', 'reason'), 'oomkilled'
  end

  test 'statuses_containing_terminated_reason - without terminated' do
    w = default_website

    web_status = WebsiteStatus.log(
      w,
      [
        {
          status: {
            containerStatuses: [
              {
                what: 0,
                is: 1,
                lastState: {
                  nonterminated: {
                    dummy: '123456'
                  }
                }
              }
            ]
          }
        }
      ]
    )

    statuses = web_status.statuses_containing_terminated_reason('oomkilled')

    assert_equal statuses.length, 0
  end
end
