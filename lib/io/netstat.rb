
module Io
  class Netstat
    # Netstat has the following format with for example netstat -tl:

    # Active Internet connections (only servers)
    # Proto Recv-Q Send-Q Local Address           Foreign Address         State
    # tcp        0      0 :::http                 :::*                    LISTEN

    # another example

    # Active Internet connections (only servers)
    # Proto Recv-Q Send-Q Local Address           Foreign Address         State
    # tcp        0      0 localhost:3000          0.0.0.0:*               LISTEN

    def self.parse(cmd_output, opts = {})
      return {} unless cmd_output

      protocols = opts[:only_protocol] ? [opts[:only_protocol]] : %w[tcp udp]

      cmd_output.lines.select do |l|
        protocols.any? { |protocol| l.starts_with?(protocol) }
      end
                .map do |line|
        parts = line.gsub(/\s+/m, ' ').split(' ')

        return {} unless parts&.length == 6

        result = {
          protocol: parts.first,
          recv_q: parts[1],
          send_q: parts[2],
          local_addr: Netstat.decode_addr(parts[3]),
          foreign_addr: Netstat.decode_addr(parts[4]),
          state: parts[5].downcase
        }

        result
      end
    end

    def self.local_addr_ports(netstats)
      netstats
        .map { |netstat| netstat&.dig(:local_addr, :port) }
        .filter { |port| port }
    end

    def self.addr_host_to_all?(addr)
      [':::', '0.0.0.0'].include?(addr[:hostname])
    end

    def self.addr_port_available?(addr, port_choices = [])
      (port_choices + ['*']).include?(addr[:port])
    end

    def self.decode_addr(addr)
      parts_double_dot = addr.split(':')

      port = parts_double_dot&.last.to_s.downcase
      hostname = parts_double_dot.length == 4 ? ':::' : parts_double_dot.first

      {
        port: port,
        hostname: hostname
      }
    end
  end
end
