
module CloudProvider
  class Manager
    attr_accessor :clouds
    attr_accessor :application

    @@instance = nil

    def initialize(file_path_configs)
      @content = YAML.load_file(file_path_configs)

      @application = @content["application"]
      @clouds = @application["clouds"]

      if @clouds.present?
        @clouds.each do |cloud|
          cloud["instance"] =
            "CloudProvider::#{cloud["type"].capitalize}".constantize.new(cloud)
        end
      end
    end

    def base_hostname
      @application["base_hostname"] || "http://unknown/"
    end

    def internal_domains
      domains = [@application["base_hostname"]]

      if @application["hostname_private_cloud"]
        domains << @application["hostname_private_cloud"]
      end

      domains
    end

    def application
      @application
    end

    def first_of_type(type)
      cloud = @clouds.find { |c| c["type"] == type }

      cloud ? cloud["instance"] : nil
    end

    def first_of_internal_type(type)
      cloud = @clouds.find { |c| c["instance"].type == type }

      cloud ? cloud["instance"] : nil
    end

    def self.instance
      unless @@instance
        openode_path =
          File.join(Rails.root, "config", ".#{ENV["RAILS_ENV"]}.openode.yml")

        begin
          @@instance = Manager.new(openode_path)
        rescue => ex
          Rails.logger.info "Unable to read #{openode_path}, #{ex}"
          Rails.logger.info ex.inspect
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
        .map { |cloud| cloud["instance"].plans }
        .flatten
    end

    def available_plans_of_type_at(type, location_str_id)
      provider = self.first_of_internal_type(type)
      provider.plans_at(location_str_id)
    end

    # for tests
    def self.clear_instance
      @@instance = nil
    end

  end
end
