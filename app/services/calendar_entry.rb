# One item on the calendar page, whether it came from Google or from the database.
CalendarEntry = Struct.new(
  :title, :start_time, :status, :assignee, :link, :external, :source, :overdue,
  keyword_init: true
) do
  def tooltip
    [title, status.to_s.humanize, assignee.presence || "Unassigned"].join(" · ")
  end
end