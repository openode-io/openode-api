require 'net/ssh'

module Remote
  # Sshing
  class Ssh
    @@conn_test = nil

    def self.set_conn_test(conn)
      @@conn_test = conn if ENV['RAILS_ENV'] == 'test'
    end

    def self.get_conn_test
      @@conn_test
    end

    def initialize(opts = {})
      @opts = opts

      unless @@conn_test
        @ssh = Net::SSH.start(opts[:host], opts[:user], password: opts[:password],
                                                        non_interactive: true)
      end

      ObjectSpace.define_finalizer(self, self.class.finalize(@ssh))
    end

    def close
      @ssh&.close
      @ssh = nil
    end

    def self.finalize(ssh)
      proc do
        ssh.close if ssh.present?
      end
    end

    def exec(cmds)
      @ssh = @@conn_test if @@conn_test

      ssh_exec_commands(cmds)
    end

    def ssh_exec_commands(cmds)
      cmds.map { |cmd| ssh_exec!(cmd) }
    end

    def ssh_exec!(command)
      stdout_data = ''
      stderr_data = ''
      exit_code = nil

      @ssh.open_channel do |channel|
        channel.exec(command) do |_ch, success|
          raise "FAILED: couldn't execute command (ssh.channel.exec)" unless success

          channel.on_data do |_ch, data|
            stdout_data += data
          end

          channel.on_extended_data do |_ch, _type, data|
            stderr_data += data
          end

          channel.on_request('exit-status') do |_ch, data|
            exit_code = data.read_long
          end
        end
      end

      @ssh.loop

      {
        stdout: stdout_data,
        stderr: stderr_data,
        exit_code: exit_code
      }
    end
  end
end
