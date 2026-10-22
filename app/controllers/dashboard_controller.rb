class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_manager, only: [:index]

  def index
    @total_projects = Project.count
    @total_tasks = Task.count
    @pending_tasks = Task.where(status: "pending").count
    @in_progress_tasks = Task.where(status: "in_progress").count
    @completed_tasks = Task.where(status: "completed").count
    @total_users = User.count

    @recent_projects = Project.order(created_at: :desc).limit(5)
    @recent_tasks = Task.order(created_at: :desc).limit(5)
  end

end
