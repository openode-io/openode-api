
module CloudProvider
  class Manager

    @@instance = nil

    def initialize(file_path_configs)
      @content = YAML.load_file(file_path_configs)

      @application = @content["application"]
      @clouds = @application["clouds"]

      if @clouds.present?
        @clouds.each do |cloud|
          puts "should init.. #{cloud} "
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

  end
end
