class CalendarsController < ApplicationController
  before_action :authenticate_user!

  def project
    @project = Project.find(params[:project_id])
    authorize @project, :show?

    @tasks = @project.tasks.includes(:user).where.not(due_date: nil)
  end

  def mine
    @tasks = current_user.tasks.includes(:user).where.not(due_date: nil)
  end
end