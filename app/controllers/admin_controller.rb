class AdminController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def index
    @total_users = User.count
    @total_managers = User.where(role: "manager").count
    @total_projects = Project.count
    @total_tasks = Task.count

    @recent_users = User.order(created_at: :desc).limit(5)
    @recent_projects = Project.order(created_at: :desc).limit(5)
    @recent_tasks = Task.order(created_at: :desc).limit(5)
  end
end