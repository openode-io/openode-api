module DeploymentMethod
  class GcloudRun < Base
    attr_accessor :ex_return, :ex_history, :ex_stdout_return, :ex_stdout_history

    def ex(cmd, options = {})
      @ex_history ||= []
      @ex_history << { cmd: cmd, options: options }
      @ind_ex_return ||= -1
      @ind_ex_return += 1

      @ex_return[@ind_ex_return]
    end

    def ex_stdout(cmd, options_cmd = {}, _global_options = {})
      @ex_stdout_history ||= []
      @ex_stdout_history << { cmd: cmd, options: options_cmd }
      @ind_ex_stdout_return ||= -1
      @ind_ex_stdout_return += 1

      @ex_stdout_return[@ind_ex_stdout_return]
    end
  end
end

class ActiveSupport::TestCase
end
