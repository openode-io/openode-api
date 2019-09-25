require 'net/ssh'

module Remote
  class Ssh
    @@conn_test = nil

    def self.set_conn_test(conn)
      @@conn_test = conn if ENV["RAILS_ENV"] == "test"
    end

    def self.get_conn_test
      @@conn_test
    end

    # opts: { host, user, password,  }
    def self.exec(cmds, opts = {})
      results = []

      if @@conn_test
        results = Ssh.ssh_exec_commands(@@conn_test, cmds)
      else

        # TODO keep the connection https://net-ssh.github.io/ssh/v1/chapter-2.html

        ssh = Net::SSH.start(opts[:host], opts[:user], :password => opts[:password],
          :non_interactive => true)
        results = Ssh.ssh_exec_commands(ssh, cmds)
        ssh.close
      end

      results
    end

    def self.ssh_exec_commands(ssh, cmds)
      cmds.map { |cmd| Ssh.ssh_exec!(ssh, cmd) }
    end

    def self.ssh_exec!(ssh, command)
      stdout_data = ""
      stderr_data = ""
      exit_code = nil

      ssh.open_channel do |channel|
        channel.exec(command) do |ch, success|
          unless success
            raise "FAILED: couldn't execute command (ssh.channel.exec)"
          end
          channel.on_data do |ch,data|
            stdout_data += data
          end

          channel.on_extended_data do |ch,type,data|
            stderr_data += data
          end

          channel.on_request("exit-status") do |ch,data|
            exit_code = data.read_long
          end
        end
      end

      ssh.loop

      {
        stdout: stdout_data,
        stderr: stderr_data,
        exit_code: exit_code
      }
    end
  end
end
