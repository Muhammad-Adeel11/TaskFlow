class ProjectsController < ApplicationController
  before_action :authenticate_user!

  def index
    @q = policy_scope(Project).ransack(params[:q])
    @q.sorts = "id asc" if @q.sorts.empty?
    @projects = @q.result.page(params[:page]).per(6)
  end

  def new
    @project = Project.new
    authorize @project
  end

  def create
    @project = Project.new(project_params)
    authorize @project

    if @project.save
      redirect_to projects_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @project = Project.find(params[:id])
    authorize @project

    @q = @project.tasks.ransack(params[:q])
    @q.sorts = "due_date asc" if @q.sorts.empty?

    respond_to do |format|
      format.html do
        @users = User.order(:name)
        @tasks = @q.result.includes(:user).page(params[:page]).per(5)

        @memberships = @project.memberships.includes(:user).sort_by { |m| m.user.name.to_s.downcase }
        @available_users = User.where.not(id: @project.member_ids).order(:name)
      end

      format.pdf do
        send_data ProjectReportPdf.new(@project, @q.result.includes(:user)).render,
                  filename: "#{@project.name.parameterize}-report.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      end
    end
  end

  def edit
    @project = Project.find(params[:id])
    authorize @project
  end

  def update
    @project = Project.find(params[:id])
    authorize @project

    if @project.update(project_params)
      redirect_to project_path(@project)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project = Project.find(params[:id])
    authorize @project

    @project.destroy
    redirect_to projects_path, status: :see_other
  end

  private

  def project_params
    params.require(:project).permit(:name, :description)
  end
end