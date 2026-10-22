class BoardsController < ApplicationController
  before_action :authenticate_user!

  def show
    @project = Project.find(params[:project_id])
    authorize @project, :show?

    tasks = @project.tasks.includes(:user)
                    .order(Arel.sql("tasks.due_date IS NULL, tasks.due_date ASC"))
    tasks = tasks.where(user_id: current_user.id) if params[:mine] == "1"

    @tasks_by_status = tasks.group_by(&:status)
  end
end