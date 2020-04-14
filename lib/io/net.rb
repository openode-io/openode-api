
module Io
  class Net
    # example
    #        Receive part         Transmit
    #  face |bytes    packets ...|bytes    packets ...
    def self.parse_header_proc_net_dev(header_fields_s)
      parts = header_fields_s
              .gsub(/\s+/m, ' ')
              .split("|")
              .map { |part| part.split(' ') }

      raise "Invalid header format" if parts.count != 3

      raise "First receive part should be bytes" unless parts[1].first == 'bytes'
      raise "First transmit part should be bytes" unless parts[2].first == 'bytes'

      parts[1][0] = 'rcv_bytes'
      parts[2][0] = 'tx_bytes'

      parts.flatten
    end

    def self.parse_proc_net_dev(content, opts = {})
      return {} unless content

      lines = content.lines

      raise "Invalid proc net dev format" if lines.count < 3

      # Remove: Inter-| Receive |  Transmit
      lines.shift

      # face |bytes ... |bytes packets ...
      header_fields_s = lines.shift
      header = Net.parse_header_proc_net_dev(header_fields_s)

      parsed_lines = lines
                     .map { |l| l.strip.gsub(':', '').gsub(/\s+/m, ' ') }
                     .map { |l| l.split(' ') }

      index_rcv_bytes = header.index('rcv_bytes')
      index_tx_bytes = header.index('tx_bytes')

      parsed_lines
        .map do |line|
        {
          'interface' => line.first,
          'rcv_bytes' => line[index_rcv_bytes]&.to_f,
          'tx_bytes' => line[index_tx_bytes]&.to_f
        }
      end
        .select do |line|
        if opts[:exclude_interfaces].present?
          !opts[:exclude_interfaces].include?(line['interface'])
        else
          true
        end
      end
    end

    def self.sum_metric(lines, metric)
      lines.map { |l| l[metric] || 0 }.sum
    end

    def self.get_new_metric_of(lines, previous_lines, metric_name)
      new_metric = Net.sum_metric(lines, metric_name)

      return new_metric unless previous_lines

      old_metric = Net.sum_metric(previous_lines, metric_name)

      new_metric < old_metric ? new_metric : (new_metric - old_metric)
    end

    def self.diff(current_net_metrics, previous_net_metrics)
      rcv_bytes = Net.get_new_metric_of(current_net_metrics, previous_net_metrics, 'rcv_bytes')
      tx_bytes = Net.get_new_metric_of(current_net_metrics, previous_net_metrics, 'tx_bytes')

      {
        'rcv_bytes' => rcv_bytes,
        'tx_bytes' => tx_bytes
      }
    end
  end
end
