class CollaboratorsController < InstancesController
  before_action except: [] do
    requires_access_to(Website::PERMISSION_ROOT)
  end

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

  def create
    json(Collaborator.create!(permitted_params.merge('website_id' => @website.id)))
  end

  def destroy
    collaborator = @website.collaborators.find_by! id: params['id']

    collaborator.destroy!

    json({})
  end

  protected

  def permitted_params
    params.require(:collaborator).permit(:user_id, permissions: [])
  end
end
