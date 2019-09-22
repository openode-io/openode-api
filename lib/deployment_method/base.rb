module DeploymentMethod

  class Base

  	REMOTE_PATH_API_LIB = "/root/openode-www/api/lib"

    private
    def require_fields(fields, options)
      fields.each do |field|
        assert options[field]
      end
    end

  end

end