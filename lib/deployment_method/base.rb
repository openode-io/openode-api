module DeploymentMethod

  class Base

  	REMOTE_PATH_API_LIB = "/root/openode-www/api/lib"

  	def files_listing(options = {})
      require_fields([:path], options)
  		path = options[:path]

  		remote_js = "'use strict';; " +
  			"const lfiles  = require('./lfiles');; " +
  			"const result = lfiles.filesListing('#{path}', '#{path}');; " +
  			"console.log(JSON.stringify(result));"
  		
      	"cd #{REMOTE_PATH_API_LIB} && " +
      	"node -e \"#{remote_js}\""
  	end

    def ensure_remote_repository(options = {})
      require_fields([:path], options)
      "mkdir -p #{options[:path]}"
    end

    def uncompress_remote_archive(options = {})
      require_fields([:archive_path, :repo_dir], options)
      arch_path = options[:archive_path]
      repo_dir = options[:repo_dir]

      "unzip -o #{arch_path} ; " +
      "rm -f #{arch_path} ;" +
      "chmod -R 755 #{repo_dir}"
    end

    private
    def require_fields(fields, options)
      fields.each do |field|
        assert options[field]
      end
    end

  end

end