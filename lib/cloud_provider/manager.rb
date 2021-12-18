module CloudProvider
  class Manager
    attr_accessor :clouds, :application

    @@instance = nil

    def self.get_config(file_path)
      YAML.load_file(file_path)
    end

    def initialize(file_path_configs)
      @content = Manager.get_config(file_path_configs)

      @application = @content['application']
      @clouds = @application['clouds']

      return if @clouds.blank?

      @clouds.each do |cloud|
        cloud['instance'] =
          "CloudProvider::#{cloud['type'].camelize}".constantize.new(cloud)
      end
    end

    def docker_build_server
      # get one among any of the build servers
      nb_build_servers = @application['docker']['build_servers'].length
      @application['docker']['build_servers'][rand(nb_build_servers)]
    end

    def docker_images_location
      @application['docker']['images_location']
    end

    def base_hostname
      @application['base_hostname'] || 'http://unknown/'
    end

    def internal_domains
      domains = [@application['base_hostname']]

      domains << @application['hostname_private_cloud'] if @application['hostname_private_cloud']

      domains
    end

    def first_of_type(type)
      cloud = @clouds.find { |c| c['type'] == type || c['cloud_type'] == type }

      cloud ? cloud['instance'] : nil
    end

    def first_details_of_type(type)
      @clouds.find { |c| c['type'] == type }
    end

    def first_of_internal_type(type)
      cloud = @clouds.find { |c| c['instance'].type == type }

      cloud ? cloud['instance'] : nil
    end

    def self.config_path
      Rails.root.join('config', ".#{ENV['RAILS_ENV']}.openode.yml")
    end

    def self.instance
      unless @@instance
        openode_path = Manager.config_path

        begin
          @@instance = Manager.new(openode_path)
        rescue StandardError => e
          Rails.logger.info "Unable to read #{openode_path}, #{e}"
          Rails.logger.info e.inspect
        end
      end

      @@instance
    end

    def self.base_hostname
      CloudProvider::Manager.instance.base_hostname
    end

    def available_locations
      Location.all.order(str_id: :asc).map do |l|
        {
          id: l.str_id,
          name: l.full_name,
          country_fullname: l.country_fullname
        }
      end
    end

    def available_plans
      @clouds
        .map { |cloud| cloud['instance'].plans }
        .flatten
        .uniq { |plan| plan[:internal_id] }
    end

    def available_plans_of_type_at(type, location_str_id)
      provider = first_of_internal_type(type)

      provider.plans_at(location_str_id)
    end

    # for tests
    def self.clear_instance
      @@instance = nil
    end
  end
end
