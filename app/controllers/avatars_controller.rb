class AvatarsController < ApplicationController
  before_action :authenticate_user!

  def destroy
    user = current_user.admin? ? User.find(params[:user_id]) : current_user

    user.avatar.purge
    redirect_to edit_user_path(user), notice: "Profile photo removed.", status: :see_other
  end
end