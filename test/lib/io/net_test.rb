
require 'test_helper'

class LibIoNetTest < ActiveSupport::TestCase
  test 'parse_header_proc_net_dev' do
    head = " face |bytes    packets errs drop fifo frame compressed multicast|" \
            "bytes    packets errs drop fifo colls carrier compressed"
    parsed_head = Io::Net.parse_header_proc_net_dev(head)

    assert_equal parsed_head.index("rcv_bytes"), 1
    assert_equal parsed_head.index("tx_bytes"), 9
  end

  test 'parse_proc_net_dev - test 1' do
    content = IO.read('test/fixtures/net/proc_net_dev/1')
    net_dev = Io::Net.parse_proc_net_dev(content)

    assert_equal net_dev[0]['interface'], "eth0"
    assert_equal net_dev[0]['rcv_bytes'], 84_363_193
    assert_equal net_dev[0]['tx_bytes'], 9_758_564
    assert_equal net_dev[1]['interface'], "lo"
    assert_equal net_dev[1]['rcv_bytes'], 0
    assert_equal net_dev[1]['tx_bytes'], 0
  end

  test 'parse_proc_net_dev - test 2' do
    content = IO.read('test/fixtures/net/proc_net_dev/2')
    net_dev = Io::Net.parse_proc_net_dev(content)

    assert_equal net_dev[0]['interface'], "eth0"
    assert_equal net_dev[0]['rcv_bytes'], 155_008
    assert_equal net_dev[0]['tx_bytes'], 571_586
    assert_equal net_dev[1]['interface'], "lo"
    assert_equal net_dev[1]['rcv_bytes'], 0
    assert_equal net_dev[1]['tx_bytes'], 0
  end

  test 'parse_proc_net_dev - test 3' do
    content = IO.read('test/fixtures/net/proc_net_dev/3')
    net_dev = Io::Net.parse_proc_net_dev(content)

    assert_equal net_dev[1]['interface'], "eth0"
    assert_equal net_dev[1]['rcv_bytes'], 1_625_040
    assert_equal net_dev[1]['tx_bytes'], 18_127_336
    assert_equal net_dev[0]['interface'], "lo"
    assert_equal net_dev[0]['rcv_bytes'], 0
    assert_equal net_dev[0]['tx_bytes'], 0
  end

  test 'parse_proc_net_dev - test 1 - excluding lo' do
    content = IO.read('test/fixtures/net/proc_net_dev/1')
    net_dev = Io::Net.parse_proc_net_dev(content, exclude_interfaces: ['lo'])

    assert_equal net_dev.count, 1
    assert_equal net_dev[0]['interface'], "eth0"
    assert_equal net_dev[0]['rcv_bytes'], 84_363_193
    assert_equal net_dev[0]['tx_bytes'], 9_758_564
  end

  test 'parse_proc_net_dev - test 1 - excluding lo and eth0' do
    content = IO.read('test/fixtures/net/proc_net_dev/1')
    net_dev = Io::Net.parse_proc_net_dev(content, exclude_interfaces: %w[lo eth0])

    assert_equal net_dev.count, 0
  end

  # sum_metric
  test 'sum_metric - happy path' do
    list = [
      {
        'rcv' => 45,
        'tx' => 5
      },
      {
        'rcv' => 45,
        'tx' => 5
      },
      {
        'tx' => 5
      }
    ]

    assert_equal Io::Net.sum_metric(list, 'rcv'), 90
    assert_equal Io::Net.sum_metric(list, 'tx'), 15
  end

  # get_new_metric_of
  test 'get_new_metric_of - happy path' do
    list = [
      {
        'rcv' => 45,
        'tx' => 5
      }
    ]

    previous_list = [
      {
        'rcv' => 30,
        'tx' => 2
      }
    ]

    assert_equal Io::Net.get_new_metric_of(list, previous_list, 'rcv'), 15
    assert_equal Io::Net.get_new_metric_of(list, previous_list, 'tx'), 3
    assert_equal Io::Net.get_new_metric_of(list, previous_list, 'invalid'), 0
  end

  test 'get_new_metric_of - has been reset' do
    list = [
      {
        'rcv' => 10,
        'tx' => 5
      }
    ]

    previous_list = [
      {
        'rcv' => 30,
        'tx' => 2
      }
    ]

    assert_equal Io::Net.get_new_metric_of(list, previous_list, 'rcv'), 10
  end

  # diff
  test 'diff - happy path' do
    list = [
      {
        'rcv_bytes' => 45,
        'tx_bytes' => 5
      }
    ]

    previous_list = [
      {
        'rcv_bytes' => 30,
        'tx_bytes' => 2
      }
    ]

    assert_equal Io::Net.diff(list, previous_list),
                 'rcv_bytes' => 15, 'tx_bytes' => 3
  end

  test 'diff - with no previous should use current' do
    list = [
      {
        'rcv_bytes' => 45,
        'tx_bytes' => 5
      }
    ]

    assert_equal Io::Net.diff(list, nil),
                 'rcv_bytes' => 45, 'tx_bytes' => 5
  end
end
