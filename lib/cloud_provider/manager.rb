
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

    def self.instance
      unless @@instance
        openode_path =
          File.join(Rails.root, "config", ".#{ENV["RAILS_ENV"]}.openode.yml")
        @@instance = Manager.new(openode_path)
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

    # for tests
    def self.clear_instance
      @@instance = nil
    end

  end
end
