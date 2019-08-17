
module CloudProvider
  class Helpers

    def self.active_clouds(cloud_types)
      what = []

      what << Internal.new
      what << Vultr.new

      what
    end

  end
end
