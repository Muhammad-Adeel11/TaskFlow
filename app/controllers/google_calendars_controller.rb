class GoogleCalendarsController < ApplicationController
  before_action :authenticate_user!

  # Step 1: send the user to Google's consent screen
  def connect
    unless GoogleCalendarService.configured?
      redirect_to my_calendar_path,
        alert: "Google credentials are missing. Add GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET to your .env file and restart the server."
      return
    end

    session[:google_oauth_state] = SecureRandom.hex(24)

    url = GoogleCalendarService.authorization_url(
      redirect_uri: redirect_uri,
      state: session[:google_oauth_state]
    )

    redirect_to url, allow_other_host: true
  end

  # Step 2: Google sends the user back here with a one-time code
  def callback
    expected_state = session.delete(:google_oauth_state).to_s

    if params[:error].present?
      redirect_to my_calendar_path, alert: "Google Calendar was not connected (you cancelled or denied access)."
      return
    end

    unless expected_state.present? && ActiveSupport::SecurityUtils.secure_compare(params[:state].to_s, expected_state)
      redirect_to my_calendar_path, alert: "The Google sign-in could not be verified. Please try again."
      return
    end

    client = GoogleCalendarService.oauth_client(redirect_uri: redirect_uri)
    client.code = params[:code]
    client.fetch_access_token!

    connection = current_user.google_connection || current_user.build_google_connection
    connection.access_token  = client.access_token
    connection.expires_at    = client.expires_at
    connection.refresh_token = client.refresh_token if client.refresh_token.present?
    connection.save!

    synced = sync_all_tasks
    redirect_to my_calendar_path, notice: "Google Calendar connected. #{synced} task#{'s' unless synced == 1} added to your TaskFlow calendar."
  rescue Signet::AuthorizationError, ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[GoogleCalendar] connect failed: #{e.class}: #{e.message}")
    redirect_to my_calendar_path, alert: "Google Calendar could not be connected. Please try again."
  end

  # Push every task of the current user again
  def sync
    if current_user.google_connection.nil?
      redirect_to my_calendar_path, alert: "Connect Google Calendar first."
      return
    end

    synced = sync_all_tasks
    redirect_to my_calendar_path, notice: "#{synced} task#{'s' unless synced == 1} synced with Google Calendar."
  end

  def destroy
    connection = current_user.google_connection

    if connection
      revoke_token(connection)
      Task.where(google_event_user_id: current_user.id).update_all(google_event_id: nil, google_event_user_id: nil)
      connection.destroy
    end

    redirect_to my_calendar_path, notice: "Google Calendar disconnected. The TaskFlow calendar still exists in your Google account, you can delete it there."
  end

  private

  def sync_all_tasks
    count = 0

    current_user.tasks.includes(:project).where.not(due_date: nil).find_each do |task|
      count += 1 if GoogleCalendarSync.push(task)
    end

    count
  end

  def revoke_token(connection)
    token = connection.refresh_token.presence || connection.access_token
    return if token.blank?

    Net::HTTP.post_form(URI("https://oauth2.googleapis.com/revoke"), "token" => token)
  rescue StandardError => e
    Rails.logger.warn("[GoogleCalendar] could not revoke token: #{e.class}: #{e.message}")
  end

    # Must match the "Authorized redirect URI" saved in Google Cloud exactly.
  def redirect_uri
    ENV["GOOGLE_REDIRECT_URI"].presence || google_calendar_callback_url
  end
end