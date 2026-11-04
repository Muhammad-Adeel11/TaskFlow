require "google/apis/calendar_v3"
require "signet/oauth_2/client"

# Builds the list of entries shown on the calendar pages.
# Connected users get their events straight from the Google Calendar API;
# everyone else (or when Google cannot be reached) sees the saved tasks.
class CalendarFeed
  include Rails.application.routes.url_helpers

  GOOGLE_ERRORS = [
    Google::Apis::Error,
    Signet::AuthorizationError,
    GoogleCalendarService::NotConnected
  ].freeze

  # Set when Google could not be reached, so the page can say so.
  attr_reader :error

  def initialize(user:, month:, project: nil)
    @user = user
    @month = month
    @project = project
  end

  def entries
    @entries ||= build
  end

  private

  def build
    return local_entries(base_tasks) if @user.google_connection.nil?

    google_entries + team_entries
  rescue *GOOGLE_ERRORS => e
    Rails.logger.warn("[GoogleCalendar] calendar page: #{e.class}: #{e.message}")
    @error = "Google Calendar could not be reached, so your saved tasks are shown instead. Try again in a moment, or reconnect Google Calendar."
    local_entries(base_tasks)
  end

  def base_tasks
    scope = @project ? @project.tasks : @user.tasks
    scope.includes(:user, :project).where.not(due_date: nil)
  end

  # Other people's tasks in this project (their events live in their own calendars)
  def team_entries
    return [] unless @project

    tasks = @project.tasks.includes(:user).where.not(due_date: nil).where.not(user_id: @user.id)
    local_entries(tasks, source: :team)
  end

  def google_entries
    from = @month.beginning_of_month - 7
    to   = @month.end_of_month + 7

    events = GoogleCalendarService.new(@user).events(from: from, to: to, project_id: @project&.id)

    events.filter_map do |event|
      date = event.start&.date || event.start&.date_time
      next if date.nil?

      props      = event.extended_properties&.private || {}
      status     = props["status"].presence || "pending"
      project_id = props["project_id"].presence

      CalendarEntry.new(
        title: event.summary.to_s,
        start_time: date.to_date,
        status: status,
        assignee: @user.name,
        link: project_id ? project_path(project_id) : event.html_link,
        external: project_id.nil?,
        source: :google,
        overdue: overdue?(date.to_date, status)
      )
    end
  end

  def local_entries(tasks, source: :local)
    tasks.map do |task|
      CalendarEntry.new(
        title: task.title,
        start_time: task.due_date,
        status: task.status,
        assignee: task.user&.name,
        link: project_path(task.project_id),
        external: false,
        source: source,
        overdue: overdue?(task.due_date, task.status)
      )
    end
  end

  def overdue?(date, status)
    date < Date.current && status != "completed"
  end
end