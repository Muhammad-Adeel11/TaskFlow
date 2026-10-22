class TasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: %i[new create edit update destroy move]

  def my_tasks
    @q = current_user.tasks.ransack(params[:q])
    @q.sorts = "due_date asc" if @q.sorts.empty?

    @tasks = @q.result.includes(:project).page(params[:page]).per(5)
    @projects = Project.where(id: current_user.tasks.select(:project_id)).order(:name)
  end

  def new
    @task = @project.tasks.build
    authorize @task
    @users = User.all
  end

  def create
    @task = @project.tasks.build(task_params)
    authorize @task

    if @task.save
      if @task.user.present?
        UserMailer.task_assigned(@task).deliver_now
      end
      redirect_to project_path(@project)
    else
      @users = User.all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @task = @project.tasks.find(params[:id])
    authorize @task
    @users = User.all
  end

  def update
    @task = @project.tasks.find(params[:id])
    authorize @task

    old_user_id = @task.user_id

    if @task.update(task_params)
      if @task.user.present? && @task.user_id != old_user_id
        TaskMailer.task_assigned(@task).deliver_now
      end

      redirect_to project_path(@project)
    else
      @users = User.all
      render :edit, status: :unprocessable_entity
    end
  end

  def update_my_status
    @task = current_user.tasks.find(params[:id])
    if @task.update(status: params[:status])
      redirect_back fallback_location: my_tasks_path, notice: "Task status updated successfully."
    else
      redirect_back fallback_location: my_tasks_path, alert: "Failed to update task status."
    end
  end

  def destroy
    @task = @project.tasks.find(params[:id])
    authorize @task

    @task.destroy
    redirect_to project_path(@project)
  end

  def move
    authorize @project, :show?

    @task = @project.tasks.find(params[:id])
    authorize @task, :move?

    status = params[:status]

    if %w[pending in_progress completed].include?(status)
      @task.update_columns(status: status, updated_at: Time.current)
      head :ok
    else
      head :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :status, :due_date, :user_id)
  end
end