
module SanitizeRequest
  def sanitize_input_cmd(hash, attribute)
    return unless hash[attribute]

    hash[attribute] = Io::Cmd.sanitize_input_cmd(hash[attribute])
  end
end
