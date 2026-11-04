require "google/apis/calendar_v3"
require "googleauth"
require "signet/oauth_2/client"

# Talks to the Google Calendar API on behalf of one user.
class GoogleCalendarService
  # Lets the app create its own "TaskFlow" calendar and manage events on it,
  # and nothing else in the user's Google account.
  SCOPE         = "https://www.googleapis.com/auth/calendar.app.created".freeze
  AUTH_URL      = "https://accounts.google.com/o/oauth2/v2/auth".freeze
  TOKEN_URL     = "https://oauth2.googleapis.com/token".freeze
  CALENDAR_NAME = "TaskFlow".freeze

  # Google event colours: 5 = yellow, 9 = blue, 10 = green
  COLORS = { "pending" => "5", "in_progress" => "9", "completed" => "10" }.freeze

  CalendarV3 = Google::Apis::CalendarV3

  class NotConnected < StandardError; end

  # ---------- sign-in with Google ----------

  def self.configured?
    ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
  end

  def self.authorization_url(redirect_uri:, state:)
    query = {
      client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: SCOPE,
      access_type: "offline", # gives us a refresh token
      prompt: "consent",
      state: state
    }.to_query

    "#{AUTH_URL}?#{query}"
  end

  def self.oauth_client(redirect_uri: nil)
    Signet::OAuth2::Client.new(
      {
        token_credential_uri: TOKEN_URL,
        client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
        client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
        redirect_uri: redirect_uri
      }.compact
    )
  end

  # ---------- calendar work ----------

  def initialize(user)
    @user = user
    @connection = user.google_connection
    raise NotConnected, "#{user.name} has not connected Google Calendar" if @connection.nil?
  end

  # Creates or updates the event for a task and returns the Google event id.
  def push(task)
    body = event_for(task)

    with_calendar_retry do |calendar|
      if task.google_event_id.present?
        begin
          service.update_event(calendar, task.google_event_id, body).id
        rescue Google::Apis::ClientError => e
          raise unless gone?(e)
          service.insert_event(calendar, body).id
        end
      else
        service.insert_event(calendar, body).id
      end
    end
  end

  def remove(event_id)
    return if @connection.calendar_id.blank?

    service.delete_event(@connection.calendar_id, event_id)
  rescue Google::Apis::ClientError => e
    raise unless gone?(e)
  end

  # Events of the TaskFlow calendar between two dates.
  def events(from:, to:, project_id: nil)
    return [] if @connection.calendar_id.blank?

    options = {
      single_events: true,
      order_by: "startTime",
      max_results: 250,
      time_min: from.in_time_zone.beginning_of_day.iso8601,
      time_max: to.in_time_zone.end_of_day.iso8601
    }
    options[:private_extended_property] = ["project_id=#{project_id}"] if project_id

    service.list_events(@connection.calendar_id, **options).items.to_a
  rescue Google::Apis::ClientError => e
    raise unless gone?(e)

    # the calendar was deleted inside Google: forget it, it is re-created on the next sync
    @connection.update!(calendar_id: nil)
    []
  end

  private

  def service
    @service ||= CalendarV3::CalendarService.new.tap do |calendar_service|
      calendar_service.client_options.application_name = "TaskFlow"
      calendar_service.authorization = fresh_authorization
    end
  end

  # Uses the saved token and asks Google for a new one when it has expired.
  def fresh_authorization
    client = self.class.oauth_client
    client.refresh_token = @connection.refresh_token
    client.access_token  = @connection.access_token
    client.expires_at    = @connection.expires_at

    if @connection.access_token.blank? || @connection.expires_at.nil? || @connection.expires_at <= 1.minute.from_now
      client.refresh!
      @connection.update!(access_token: client.access_token, expires_at: client.expires_at)
    end

    client
  rescue Signet::AuthorizationError => e
    # the user removed TaskFlow from their Google account: drop the dead connection
    @connection.destroy if e.message.include?("invalid_grant")
    raise
  end

  def calendar_id
    @connection.calendar_id.presence || create_calendar!
  end

  def create_calendar!
    calendar = CalendarV3::Calendar.new(
      summary: CALENDAR_NAME,
      description: "Tasks and due dates from TaskFlow",
      time_zone: Time.zone.tzinfo.name
    )

    id = service.insert_calendar(calendar).id
    @connection.update!(calendar_id: id)
    id
  end

  # If the TaskFlow calendar was deleted in Google, create a new one and try again.
  def with_calendar_retry
    yield calendar_id
  rescue Google::Apis::ClientError => e
    raise unless gone?(e) && @connection.calendar_id.present?

    @connection.update!(calendar_id: nil)
    yield calendar_id
  end

  def gone?(error)
    [404, 410].include?(error.status_code)
  end

  def event_for(task)
    title = task.status == "completed" ? "[Done] #{task.title}" : task.title

    CalendarV3::Event.new(
      summary: title,
      description: description_for(task),
      start: CalendarV3::EventDateTime.new(date: task.due_date),
      end: CalendarV3::EventDateTime.new(date: task.due_date + 1),
      color_id: COLORS[task.status],
      transparency: "transparent",
      extended_properties: CalendarV3::Event::ExtendedProperties.new(
        private: {
          "task_id" => task.id.to_s,
          "project_id" => task.project_id.to_s,
          "status" => task.status.to_s
        }
      )
    )
  end

  def description_for(task)
    [
      "Project: #{task.project&.name}",
      "Status: #{task.status.to_s.humanize}",
      "Assigned to: #{task.user&.name || 'Unassigned'}",
      task.description.presence
    ].compact.join("\n")
  end
end