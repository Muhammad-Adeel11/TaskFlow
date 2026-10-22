class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin, only: [:index, :destroy]
  
  def index
    @q = User.ransack(params[:q])
    @q.sorts = "name asc" if @q.sorts.empty?
    @users = @q.result.with_attached_avatar.page(params[:page]).per(5)
  end

  def show
    if current_user.admin?
      @user = User.find(params[:id])
    else
      @user = current_user
    end

    @tasks = @user.tasks
    @task_stats = @user.tasks.group(:status).count
  end

  def edit
    if current_user.admin?
      @user = User.find(params[:id])
    else
      @user = current_user
    end
  end

  def update
    @user = current_user.admin? ? User.find(params[:id]) : current_user

    attrs = user_params
    attrs = attrs.except(:password, :password_confirmation) if attrs[:password].blank?

    if @user.update(attrs)
      bypass_sign_in(@user) if @user == current_user   # stay logged in after a password change
      redirect_to user_path(@user), notice: "Profile updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user = User.find(params[:id])

    if @user == current_user
      redirect_to users_path,
                  alert: "You cannot delete your own account."
      return
    end

    @user.destroy
    redirect_to users_path
  end

  private

  def user_params
    if current_user.admin? && @user != current_user
      params.expect(user: [:name, :email, :role, :avatar])
    else
      params.expect(user: [:name, :email, :avatar, :password, :password_confirmation])
    end
  end
end