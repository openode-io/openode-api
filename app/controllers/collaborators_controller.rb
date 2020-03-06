class CollaboratorsController < InstancesController
  before_action except: [] do
    requires_access_to(Website::PERMISSION_ROOT)
  end

  api!
  def index
    result = @website.collaborators
                     .map do |c|
      {
        id: c.id,
        user: {
          id: c.user_id,
          email: c.user.email
        },
        permissions: c.permissions
      }
    end

    json(result)
  end

  api!
  def create
    c_params = permitted_params.merge('website_id' => @website.id)

    if c_params[:email]
      user = User.find_by email: c_params[:email]

      unless user
        # otherwise we need to create it and send an email to the collaborator
        tmp_passwd = Str::Rand.password
        user = User.create!(email: c_params[:email], password: tmp_passwd)

        UserMailer.with(
          user: user,
          password: tmp_passwd
        ).registration_collaborator.deliver_now
      end

      c_params[:user_id] = user.id
    end

    c_params.delete(:email)

    json(Collaborator.create!(c_params))
  end

  api!
  def update
    json(
      collaborator.update!(permitted_change_params)
    )
  end

  api!
  def destroy
    collaborator.destroy!

    json({})
  end

  protected

  def collaborator
    return @website.collaborators.find_by!(id: params['id']) if params['id']
  end

  def permitted_change_params
    params.require(:collaborator).permit(permissions: [])
  end

  def permitted_params
    params.require(:collaborator).permit(:user_id, :email, permissions: [])
  end
end
