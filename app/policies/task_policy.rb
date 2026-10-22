class TaskPolicy < ApplicationPolicy
  def create?  = user.manager?
  def update?  = user.manager?
  def destroy? = user.manager?
  def move? = user.manager? || record.user_id == user.id
end