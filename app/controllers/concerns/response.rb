
module Response
  def json_res(object, status = :ok)
    render json: object, status: status
  end
end
