# frozen_string_literal: true

module CloudProvider
  class Manager
    attr_accessor :clouds
    attr_accessor :application

    @@instance = nil

    def self.get_config(file_path)
      YAML.load_file(file_path)
    end

    def initialize(file_path_configs)
      @content = Manager.get_config(file_path_configs)

      @application = @content['application']
      @clouds = @application['clouds']

      if @clouds.present?
        @clouds.each do |cloud|
          cloud['instance'] =
            "CloudProvider::#{cloud['type'].capitalize}".constantize.new(cloud)
        end
      end
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
      cloud = @clouds.find { |c| c['type'] == type }

      cloud ? cloud['instance'] : nil
    end

    def first_of_internal_type(type)
      cloud = @clouds.find { |c| c['instance'].type == type }

      cloud ? cloud['instance'] : nil
    end

    def self.config_path
      File.join(Rails.root, 'config', ".#{ENV['RAILS_ENV']}.openode.yml")
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
