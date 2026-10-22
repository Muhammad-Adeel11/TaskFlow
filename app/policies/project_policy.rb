class ProjectPolicy < ApplicationPolicy
  def show?
    user.admin? || user.manager? || record.memberships.exists?(user_id: user.id)
  end

  def create?         = user.manager?
  def update?         = user.manager?
  def destroy?        = user.manager?
  def manage_members? = user.manager?

  class Scope < Scope
    def resolve
      if user.admin? || user.manager?
        scope.all
      else
        scope.where(id: user.memberships.select(:project_id))
      end
    end
  end
end