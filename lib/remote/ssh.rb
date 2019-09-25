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

    def initialize(opts = {})
      @opts = opts

      unless @@conn_test
        @ssh = Net::SSH.start(opts[:host], opts[:user], :password => opts[:password],
            :non_interactive => true)
      end

      ObjectSpace.define_finalizer( self, self.class.finalize(@ssh) )
    end

    def close
      @ssh.close if @ssh
      @ssh = nil
    end

    def self.finalize(ssh)
      proc do
        if ssh.present?
          ssh.close
        end
      end
    end

    def exec(cmds)
      results = []

      if @@conn_test
        @ssh = @@conn_test
        results = self.ssh_exec_commands(cmds)
      else
        results = self.ssh_exec_commands(cmds)
      end

      results
    end

    def ssh_exec_commands(cmds)
      cmds.map { |cmd| self.ssh_exec!(cmd) }
    end

    def ssh_exec!(command)
      stdout_data = ""
      stderr_data = ""
      exit_code = nil

      @ssh.open_channel do |channel|
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

      @ssh.loop

      {
        stdout: stdout_data,
        stderr: stderr_data,
        exit_code: exit_code
      }
    end
  end
end
