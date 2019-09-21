require 'net/sftp'

module Remote
  class Sftp
    @@conn_test = nil

    def self.set_conn_test(conn)
      @@conn_test = conn if ENV["RAILS_ENV"] == "test"
    end

    def self.get_conn_test
      @@conn_test
    end

    # opts: { host, user, password,  }
    def self.transfer(upload_files, opts = {})
      results = []

      if @@conn_test
        Rails.logger.info("Skipping SFTP transfer")
      else
        Net::SFTP.start(opts[:host], opts[:user], :password => opts[:password],
          :non_interactive => true) do |sftp|
        	Sftp.upload(sftp, upload_files)
        end
      end

      results
    end

    def self.upload(sftp, files)
		files.each do |file|
		  sftp.upload!(file[:local_file_path], file[:remote_file_path])
		end
    end
  end
end
