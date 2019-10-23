# frozen_string_literal: true

module Io
  class Dir
    def self.find_file_in(f, list_files)
      list_files.find { |f_list| f_list['path'] == f['path'] }
    end

    def self.modified_or_created_files(files_client, files_server)
      files_client.clone.map do |f|
        f_server = Dir.find_file_in(f, files_server)

        if f_server
          if (f['checksum'] && f_server['checksum'] && f['checksum'] != f_server['checksum']) ||
             (
                (!f['checksum'] || !f_server['checksum']) &&
                (f['mtime'] > f_server['mtime'] || f['size'] != f_server['size'])
              )
            f['change'] = 'M' # Modified
            f['modified'] = true
          end
        else
          f['change'] = 'C' # Created
          f['modified'] = true
         end

        f
      end
                  .select { |f| f['modified'] }
    end

    def self.should_exclude?(f, dirs_to_exclude)
      dirs_to_exclude.find do |dir_exclude|
        f['path'].include?(dir_exclude) ||
          dir_exclude.include?(f['path']) ||
          "#{f['path']}/".include?(dir_exclude)
      end
    end

    def self.deleted_files(files_client, files_server, dirs_to_exclude = [])
      files_server.clone.map do |f|
        if !Dir.find_file_in(f, files_client) && !Dir.should_exclude?(f, dirs_to_exclude)
          f['change'] = 'D' # Delete
          f['modified'] = true
        end

        f
      end
                  .select { |f| f['modified'] }
    end

    # do the diff between client and server files
    def self.diff(files_client, files_server, dir_to_exclude = [])
      Dir.modified_or_created_files(files_client, files_server) +
        Dir.deleted_files(files_client, files_server, dir_to_exclude)
    end
  end
end
