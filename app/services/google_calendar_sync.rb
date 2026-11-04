# Keeps a task and its Google Calendar event in step.
# A failure here is only logged, so saving a task never breaks because of Google.
class GoogleCalendarSync
  def self.push(task)
    new(task).push
  end

  def self.remove(task)
    new(task).remove
  end

  def initialize(task)
    @task = task
  end

  # Returns true when everything went fine.
  def push
    owner = @task.user

    # reassigned to someone else, or the due date was removed: take the old event away
    if @task.google_event_id.present? && (@task.google_event_user_id != owner&.id || @task.due_date.nil?)
      remove_old_event
    end

    return true if @task.due_date.nil? || owner&.google_connection.nil?

    event_id = GoogleCalendarService.new(owner).push(@task)
    @task.update_columns(google_event_id: event_id, google_event_user_id: owner.id)
    true
  rescue StandardError => e
    log("could not sync task ##{@task.id}", e)
    false
  end

  def remove
    return if @task.google_event_id.blank?

    owner = User.find_by(id: @task.google_event_user_id)
    GoogleCalendarService.new(owner).remove(@task.google_event_id) if owner&.google_connection
  rescue StandardError => e
    log("could not remove event of task ##{@task.id}", e)
  end

  private

  def remove_old_event
    previous_owner = User.find_by(id: @task.google_event_user_id)

    if previous_owner&.google_connection
      GoogleCalendarService.new(previous_owner).remove(@task.google_event_id)
    end
  rescue StandardError => e
    log("could not remove old event of task ##{@task.id}", e)
  ensure
    @task.update_columns(google_event_id: nil, google_event_user_id: nil)
  end

  def log(message, error)
    Rails.logger.warn("[GoogleCalendar] #{message}: #{error.class}: #{error.message}")
  end
end