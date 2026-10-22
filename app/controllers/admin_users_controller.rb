class AdminUsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def new
    @user = User.new
  end

  def create
    @user = User.new(admin_user_params)

    if @user.save
      @user.confirm
      redirect_to users_path,
                  notice: "User created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def admin_user_params
    params.require(:user).permit(
      :name,
      :email,
      :password,
      :password_confirmation,
      :role
    )
  end
end