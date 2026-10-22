class MembershipsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project

  def create
    authorize @project, :manage_members?

    membership = @project.memberships.build(user_id: params[:user_id])

    if membership.save
      redirect_to project_path(@project), notice: "Member added."
    else
      redirect_to project_path(@project), alert: membership.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @project, :manage_members?

    membership = @project.memberships.find(params[:id])

    if @project.tasks.exists?(user_id: membership.user_id)
      redirect_to project_path(@project), alert: "Reassign this member's tasks before removing them."
    else
      membership.destroy
      redirect_to project_path(@project), notice: "Member removed."
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end
end