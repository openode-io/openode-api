module DeploymentMethod

  class Base

  	REMOTE_PATH_API_LIB = "/root/openode-www/api/lib"

  	def files_listing(options = {})
  		assert options[:path]
  		path = options[:path]

  		remote_js = "'use strict';; " +
  			"const lfiles  = require('./lfiles');; " +
  			"const result = lfiles.filesListing('#{path}', '#{path}');; " +
  			"console.log(JSON.stringify(result));"
  		
      	"cd #{REMOTE_PATH_API_LIB} && " +
      	"node -e \"#{remote_js}\""
  	end

  end

end