
module CloudProvider
  class Dummy < Base

    def initialize(configs)
    end

    def available_locations
      [
        {
          id: "canada3",
          name: "Toronto (Canada)",
          country_fullname: "Canada3"
        }
      ]
    end

  end
end
