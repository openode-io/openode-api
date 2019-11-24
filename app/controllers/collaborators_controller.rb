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
end
