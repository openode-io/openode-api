class ConfigsController < InstancesController

  before_action :extract_variable

  def get_config
    json_res({
      result: "success",
      value: @website.configs[@var_name]
    })
  end

  def set_config
    config = Website.config_def(@var_name)
    value = params["value"]

    if config[:enum] && ! config[:enum].include?(value)
      msg = "Invalid value, valid ones: #{config[:enum]}"
      raise ApplicationRecord::ValidationError.new(msg)
    end

    if config[:min] && config[:max]
      parsed_val = value.to_f

      if ! (parsed_val.present? && parsed_val >= config[:min] && parsed_val <= config[:max])
        msg = "Invalid value, min = #{config[:min]}, max = #{config[:max]}"
        raise ApplicationRecord::ValidationError.new(msg)
      end
    end

    @website.configs ||= {}

    @website.configs["#{@var_name}"] = value

    if config[:type] == "website"
      # save in website object
      @website[@var_name.downcase] = value
    end

    @website.save!

    @website.reload

    json_res({
      result: "success",
      configs: @website.configs
    })
  end

  private

  def extract_variable
    @var_name = params["variable"]

    if ! Website.valid_config_variable?(@var_name)
      msg = "Invalid variable name, Run openode available-configs for the list of valid variables."
      raise ApplicationRecord::ValidationError.new(msg)
    end
  end

end
