class ApplicationController < ActionController::Base

  include Pundit::Authorization
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  helper_method :current_user

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(
      :sign_up,
      keys: [:name]
    )

    devise_parameter_sanitizer.permit(
      :account_update,
      keys: [:name]
    )
  end

  def after_sign_in_path_for(resource)
    if resource.admin?
      admin_dashboard_path
    elsif resource.manager?
      dashboard_path
    else
      projects_path
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end

  private

  def require_manager
    redirect_to projects_path unless current_user&.manager?
  end

  def require_admin
    redirect_to projects_path unless current_user&.admin?
  end

  def user_not_authorized
    respond_to do |format|
      format.html { redirect_to projects_path, alert: "You are not authorized to do that." }
      format.any  { head :forbidden }
    end
  end
end