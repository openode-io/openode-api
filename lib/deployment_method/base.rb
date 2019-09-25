module DeploymentMethod

  class Base

  	attr_accessor :runner

  	REMOTE_PATH_API_LIB = "/root/openode-www/api/lib"

  	protected
  	def ex(cmd, options = {})
  		self.runner.execute([{ cmd_name: cmd, options: options }]).first
  	end

  	def ex_stdout(cmd, options = {})
  		self.runner.execute([{ cmd_name: cmd, options: options }]).first[:stdout]
  	end

    private
    def require_fields(fields, options)
      fields.each do |field|
        assert options[field]
      end
    end

  end

end