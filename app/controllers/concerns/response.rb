module Response
  def json(object, status = :ok)
    render json: object, status: status
  end
end
