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
    json(Collaborator.create!(permitted_params.merge('website_id' => @website.id)))
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
    params.require(:collaborator).permit(:user_id, permissions: [])
  end
end
