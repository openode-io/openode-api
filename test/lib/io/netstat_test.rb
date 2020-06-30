
require 'test_helper'

class LibIoNetstatTest < ActiveSupport::TestCase
  test 'parse with localhost port 3000' do
    input = 'Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State
tcp        0      0 localhost:3000          0.0.0.0:*               LISTEN'
    result = Io::Netstat.parse(input, only_protocol: 'tcp')

    assert_equal result.length, 1
    assert_equal result.first[:protocol], 'tcp'
    assert_equal result.first[:state], 'listen'
    assert_equal result.first[:local_addr][:port], '3000'
    assert_equal result.first[:local_addr][:hostname], 'localhost'
    assert_equal result.first[:foreign_addr][:port], '*'
    assert_equal result.first[:foreign_addr][:hostname], '0.0.0.0'
  end

  test 'local_addr_ports - happy path' do
    input = 'Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State
tcp        0      0 localhost:3000          0.0.0.0:*               LISTEN'
    netstats = Io::Netstat.parse(input, only_protocol: 'tcp')

    assert_equal Io::Netstat.local_addr_ports(netstats), ['3000']
  end

  test 'decode_addr - host:port' do
    result = Io::Netstat.decode_addr("localhost:3000")

    assert_equal result[:port], "3000"
    assert_equal result[:hostname], "localhost"
  end

  test 'decode_addr - :::port' do
    result = Io::Netstat.decode_addr(":::3000")

    assert_equal result[:port], "3000"
    assert_equal result[:hostname], ":::"
  end

  test 'decode_addr - 127.0.0.1:*' do
    result = Io::Netstat.decode_addr("127.0.0.1:*")

    assert_equal result[:port], "*"
    assert_equal result[:hostname], "127.0.0.1"
  end

  test 'addr_host_to_all? - when ip' do
    result = Io::Netstat.addr_host_to_all?(hostname: '127.0.0.1')
    assert_equal result, false
  end

  test 'addr_host_to_all? - when :::' do
    result = Io::Netstat.addr_host_to_all?(hostname: ':::')
    assert_equal result, true
  end

  test 'addr_host_to_all? - when 0.0.0.0' do
    result = Io::Netstat.addr_host_to_all?(hostname: '0.0.0.0')
    assert_equal result, true
  end

  # addr_port_available?
  test 'addr_port_available? - when 3000' do
    result = Io::Netstat.addr_port_available?({ port: '3000' }, ['3000'])
    assert_equal result, true
  end

  test 'addr_port_available? - when http' do
    result = Io::Netstat.addr_port_available?({ port: 'http' }, %w[80 http])
    assert_equal result, true
  end

  test 'addr_port_available? - when not http' do
    result = Io::Netstat.addr_port_available?({ port: '2000' }, %w[80 http])
    assert_equal result, false
  end
end
