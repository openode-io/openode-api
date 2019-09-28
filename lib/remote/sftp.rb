require 'net/sftp'

module Remote
  class Sftp
    @@conn_test = nil

    def self.set_conn_test(conn)
      @@conn_test = conn if ENV["RAILS_ENV"] == "test"
      @@test_uploaded_files = [] if ENV["RAILS_ENV"] == "test"
    end

    def self.get_conn_test
      @@conn_test
    end

    def self.get_test_uploaded_files
      @@test_uploaded_files
    end

    # opts: { host, user, password,  }
    def self.transfer(upload_files, opts = {})
      if @@conn_test
        Rails.logger.info("Skipping SFTP transfer")
        @@test_uploaded_files = upload_files
      else
        Net::SFTP.start(opts[:host], opts[:user], :password => opts[:password],
          :non_interactive => true) do |sftp|
        	Sftp.upload(sftp, upload_files)
        end
      end
    end

    def self.content_to_tmp_file(content)
      dir_tmp = "/tmp/"
      file_tmp_path = "#{dir_tmp}#{SecureRandom.hex(32)}"

      File.write(file_tmp_path, content)

      file_tmp_path
    end

    def self.upload(sftp, files)
  		files.each do |file|
        tmp_file_path = nil

        if file[:content]
          tmp_file_path = Sftp.content_to_tmp_file(file[:content])
          file[:local_file_path] = tmp_file_path
          Rails.logger.info("Wrote tmp upload file #{tmp_file_path}")
        end

        Rails.logger.info("Uploading #{file[:local_file_path]} to #{file[:remote_file_path]}")
  			sftp.upload!(file[:local_file_path], file[:remote_file_path])

        if tmp_file_path.present?
          Rails.logger.info("Removing tmp upload file #{tmp_file_path}")
          File.delete(tmp_file_path)
        end
  		end
    end
  end
end
