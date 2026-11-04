class CalendarsController < ApplicationController
  before_action :authenticate_user!

  def project
    @project = Project.find(params[:project_id])
    authorize @project, :show?

    feed = CalendarFeed.new(user: current_user, month: calendar_month, project: @project)
    @entries = feed.entries
    @google_error = feed.error
  end

  def mine
    feed = CalendarFeed.new(user: current_user, month: calendar_month)
    @entries = feed.entries
    @google_error = feed.error
  end

  private

  # simple_calendar's next / previous links send ?start_date=YYYY-MM-DD
  def calendar_month
    Date.parse(params[:start_date].to_s).beginning_of_month
  rescue ArgumentError
    Date.current.beginning_of_month
  end
end