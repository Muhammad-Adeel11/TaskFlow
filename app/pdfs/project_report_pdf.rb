require "prawn"
require "prawn/table"

# Builds the project report PDF.
# Usage: ProjectReportPdf.new(project, tasks, generated_by: current_user).render
class ProjectReportPdf
  # ---------- palette (matches the TaskFlow app) ----------
  INK    = "0E1020".freeze
  TEXT   = "2A2E45".freeze
  MUTED  = "6B7090".freeze
  FAINT  = "A3A8C0".freeze
  BORDER = "E4E6F0".freeze
  SOFT   = "F6F7FB".freeze
  ACCENT = "4F46E5".freeze
  DANGER = "BE123C".freeze
  WHITE  = "FFFFFF".freeze

  STATUSES = {
    "pending"     => { label: "Pending",     color: "B45309", bar: "E0A93B" },
    "in_progress" => { label: "In progress", color: "1D4ED8", bar: "5B7CFA" },
    "completed"   => { label: "Completed",   color: "15803D", bar: "2FAE7B" }
  }.freeze

  DONE_STATUSES = %w[completed done].freeze

  MARGIN_TOP  = 56
  BAND_HEIGHT = 150

  def initialize(project, tasks, generated_by: nil)
    @project      = project
    @tasks        = tasks.to_a
    @generated_by = generated_by

    @pdf = Prawn::Document.new(
      page_size: "A4",
      margin: [MARGIN_TOP, 48, 64, 48],
      info: {
        Title: "#{safe(project.name)} - Project Report",
        Author: "TaskFlow",
        Creator: "TaskFlow",
        CreationDate: Time.current
      }
    )
    @pdf.font "Helvetica"
  end

  def render
    cover_band
    meta_row
    kpi_cards
    status_breakdown
    tasks_section
    workload_section
    running_header
    footer
    @pdf.render
  end

  private

  # ---------- Cover band (first page only) ----------
  def cover_band
    @pdf.canvas do
      page_w = @pdf.bounds.width
      top    = @pdf.bounds.top
      left   = 48
      inner  = page_w - (left * 2)

      @pdf.fill_color INK
      @pdf.fill_rectangle [0, top], page_w, BAND_HEIGHT
      @pdf.fill_color ACCENT
      @pdf.fill_rectangle [0, top - BAND_HEIGHT], page_w, 3

      @pdf.fill_color WHITE
      @pdf.text_box "TaskFlow", at: [left, top - 34], width: 220,
                    size: 15, style: :bold

      @pdf.fill_color "A5B4FC"
      @pdf.text_box "PROJECT REPORT", at: [left + inner - 220, top - 33], width: 220,
                    size: 8, style: :bold, align: :right, character_spacing: 1.6

      @pdf.fill_color FAINT
      @pdf.text_box Time.current.strftime("%d %B %Y"), at: [left + inner - 220, top - 47],
                    width: 220, size: 8, align: :right

      @pdf.fill_color WHITE
      @pdf.text_box safe(@project.name), at: [left, top - 72], width: inner, height: 40,
                    size: 28, style: :bold, overflow: :shrink_to_fit, min_font_size: 15

      description = safe(@project.description.presence || "No description provided.").squish.truncate(190)
      @pdf.fill_color "C7CBE0"
      @pdf.text_box description, at: [left, top - 114], width: inner * 0.85, height: 28,
                    size: 9.5, leading: 3
    end

    @pdf.move_cursor_to @pdf.bounds.top - (BAND_HEIGHT - MARGIN_TOP + 30)
  end

  # ---------- Who / when ----------
  def meta_row
    items = [
      ["Generated",       Time.current.strftime("%d %b %Y, %H:%M")],
      ["Prepared by",     @generated_by&.name || "TaskFlow"],
      ["Team members",    @project.memberships.count.to_s],
      ["Project created", @project.created_at.strftime("%d %b %Y")]
    ]

    col_w = @pdf.bounds.width / items.size
    top   = @pdf.cursor

    items.each_with_index do |(label, value), i|
      x = i * col_w

      @pdf.fill_color MUTED
      @pdf.text_box label.upcase, at: [x, top], width: col_w - 8,
                    size: 6.5, style: :bold, character_spacing: 1

      @pdf.fill_color INK
      @pdf.text_box safe(value), at: [x, top - 13], width: col_w - 8,
                    size: 10, style: :bold
    end

    @pdf.move_cursor_to top - 38
    @pdf.stroke_color BORDER
    @pdf.line_width 0.6
    @pdf.stroke_horizontal_rule
    @pdf.move_down 26
  end

  # ---------- Four key figures ----------
  def kpi_cards
    cards = [
      ["Total tasks", @tasks.size,                               ACCENT],
      ["Completed",   count_status("completed"),                  STATUSES["completed"][:bar]],
      ["In progress", count_status("in_progress"),                STATUSES["in_progress"][:bar]],
      ["Overdue",     @tasks.count { |t| overdue?(t) },           DANGER]
    ]

    gap    = 12
    card_w = (@pdf.bounds.width - (gap * 3)) / 4.0
    card_h = 74
    top    = @pdf.cursor

    cards.each_with_index do |(label, value, color), i|
      x = i * (card_w + gap)

      @pdf.fill_color SOFT
      @pdf.fill_rounded_rectangle [x, top], card_w, card_h, 8
      @pdf.stroke_color BORDER
      @pdf.line_width 0.6
      @pdf.stroke_rounded_rectangle [x, top], card_w, card_h, 8

      @pdf.fill_color color
      @pdf.fill_rounded_rectangle [x + 14, top - 15], 20, 3, 1.5

      @pdf.fill_color INK
      @pdf.text_box value.to_s, at: [x + 14, top - 26], width: card_w - 28,
                    size: 25, style: :bold

      @pdf.fill_color MUTED
      @pdf.text_box label.upcase, at: [x + 14, top - 58], width: card_w - 28,
                    size: 6.5, style: :bold, character_spacing: 1
    end

    @pdf.move_cursor_to top - card_h - 32
  end

  # ---------- Segmented bar + legend ----------
  def status_breakdown
    ensure_space 130

    total   = @tasks.size
    done    = count_status("completed")
    percent = total.zero? ? 0 : (done * 100.0 / total).round

    section_title "Progress", right: "#{percent}% complete"

    width = @pdf.bounds.width
    y     = @pdf.cursor

    @pdf.fill_color BORDER
    @pdf.fill_rectangle [0, y], width, 7

    if total.positive?
      x = 0
      %w[completed in_progress pending].each do |status|
        count = count_status(status)
        next if count.zero?

        w = width * count / total.to_f
        @pdf.fill_color STATUSES[status][:bar]
        @pdf.fill_rectangle [x, y], w, 7
        x += w
      end
    end

    legend_top = y - 24
    col_w      = width / 3.0

    %w[completed in_progress pending].each_with_index do |status, i|
      count = count_status(status)
      share = total.zero? ? 0 : (count * 100.0 / total).round
      x     = i * col_w

      @pdf.fill_color STATUSES[status][:bar]
      @pdf.fill_circle [x + 4, legend_top - 5], 3.5

      @pdf.fill_color TEXT
      @pdf.text_box STATUSES[status][:label], at: [x + 14, legend_top],
                    width: col_w - 14, size: 9, style: :bold

      @pdf.fill_color MUTED
      @pdf.text_box "#{count} #{count == 1 ? 'task' : 'tasks'}  /  #{share}%",
                    at: [x + 14, legend_top - 13], width: col_w - 14, size: 8
    end

    @pdf.move_cursor_to legend_top - 52
  end

  # ---------- Task table ----------
  def tasks_section
    ensure_space 140
    section_title "Tasks", right: "#{@tasks.size} in total"

    if @tasks.empty?
      @pdf.fill_color MUTED
      @pdf.text "This project has no tasks yet.", size: 10
      @pdf.move_down 20
      return
    end

    rows = [%w[No. Task Assignee Due Status]]

    @tasks.each_with_index do |task, i|
      late   = overdue?(task)
      status = STATUSES.fetch(task.status.to_s, STATUSES["pending"])
      shade  = i.odd? ? SOFT : WHITE

      title = "<b>#{escape(safe(task.title))}</b>"
      if task.description.present?
        note   = escape(safe(task.description).squish.truncate(90))
        title += "\n<color rgb='#{MUTED}'><font size='7.5'>#{note}</font></color>"
      end

      due_text = task.due_date ? task.due_date.strftime("%d %b %Y") : "-"
      due_text = "#{due_text}\nOVERDUE" if late

      rows << [
        { content: format("%02d", i + 1), text_color: FAINT, size: 8, background_color: shade },
        { content: title, inline_format: true, text_color: INK, background_color: shade },
        { content: safe(task.user&.name || "Unassigned"), background_color: shade },
        { content: due_text, text_color: late ? DANGER : TEXT,
          font_style: late ? :bold : :normal, background_color: shade },
        { content: status[:label].upcase, text_color: status[:color],
          font_style: :bold, size: 7, background_color: shade }
      ]
    end

    @pdf.table(rows,
               header: true,
               width: @pdf.bounds.width,
               column_widths: { 0 => 30, 2 => 100, 3 => 78, 4 => 72 },
               cell_style: {
                 size: 9, text_color: TEXT, padding: [9, 8],
                 borders: [:bottom], border_width: 0.5, border_color: BORDER
               }) do
      row(0).background_color = INK
      row(0).text_color       = WHITE
      row(0).font_style       = :bold
      row(0).size             = 7
      row(0).padding          = [8, 8]
      row(0).borders          = []
    end

    @pdf.move_down 30
  end

  # ---------- Who carries how much ----------
  def workload_section
    return if @tasks.empty?

    ensure_space 150
    section_title "Workload by member"

    grouped = @tasks.group_by { |t| t.user&.name || "Unassigned" }
    ordered = grouped.sort_by { |name, list| [-list.size, name.to_s.downcase] }

    rows = [["Member", "Assigned", "Completed", "In progress", "Pending", "Overdue"]]

    ordered.each_with_index do |(name, list), i|
      shade   = i.odd? ? SOFT : WHITE
      late    = list.count { |t| overdue?(t) }
      numbers = [
        list.size,
        list.count { |t| t.status.to_s == "completed" },
        list.count { |t| t.status.to_s == "in_progress" },
        list.count { |t| t.status.to_s == "pending" }
      ]

      rows << [{ content: safe(name), font_style: :bold, text_color: INK, background_color: shade }] +
              numbers.map { |n| { content: n.to_s, align: :right, background_color: shade } } +
              [{ content: late.to_s, align: :right, background_color: shade,
                 text_color: late.positive? ? DANGER : TEXT,
                 font_style: late.positive? ? :bold : :normal }]
    end

    @pdf.table(rows,
               header: true,
               width: @pdf.bounds.width,
               column_widths: { 1 => 62, 2 => 66, 3 => 70, 4 => 58, 5 => 58 },
               cell_style: {
                 size: 9, text_color: TEXT, padding: [8, 8],
                 borders: [:bottom], border_width: 0.5, border_color: BORDER
               }) do
      row(0).background_color = INK
      row(0).text_color       = WHITE
      row(0).font_style       = :bold
      row(0).size             = 7
      row(0).padding          = [8, 8]
      row(0).borders          = []
      row(0).columns(1..5).align = :right
    end
  end

  # ---------- Small header on pages 2, 3, ... ----------
  def running_header
    @pdf.repeat(->(page) { page > 1 }, dynamic: true) do
      width = @pdf.bounds.width
      top   = @pdf.bounds.top

      @pdf.fill_color INK
      @pdf.text_box "TaskFlow", at: [0, top + 36], width: 150, size: 9, style: :bold

      @pdf.fill_color MUTED
      @pdf.text_box safe(@project.name).truncate(60), at: [width - 300, top + 36],
                    width: 300, size: 8, align: :right

      @pdf.stroke_color ACCENT
      @pdf.line_width 1.2
      @pdf.stroke_horizontal_line 0, width, at: top + 20
    end
  end

  # ---------- Footer on every page ----------
  def footer
    @pdf.repeat(:all, dynamic: true) do
      width = @pdf.bounds.width

      @pdf.stroke_color BORDER
      @pdf.line_width 0.5
      @pdf.stroke_horizontal_line 0, width, at: -14

      @pdf.fill_color FAINT
      @pdf.text_box "TaskFlow  /  #{safe(@project.name).truncate(60)}  /  Confidential",
                    at: [0, -22], width: width - 100, size: 7.5

      @pdf.fill_color MUTED
      @pdf.text_box "Page #{@pdf.page_number} of #{@pdf.page_count}",
                    at: [width - 100, -22], width: 100, size: 7.5, align: :right
    end
  end

  # ---------- helpers ----------
  def section_title(text, right: nil)
    top = @pdf.cursor

    @pdf.fill_color INK
    @pdf.text_box text, at: [0, top], width: 300, size: 13, style: :bold

    if right
      @pdf.fill_color MUTED
      @pdf.text_box right, at: [@pdf.bounds.width - 200, top - 3], width: 200,
                    size: 8.5, align: :right
    end

    @pdf.move_cursor_to top - 28
  end

  def ensure_space(height)
    @pdf.start_new_page if @pdf.cursor < height
  end

  def count_status(status)
    @tasks.count { |t| t.status.to_s == status }
  end

  def done?(task)
    DONE_STATUSES.include?(task.status.to_s)
  end

  def overdue?(task)
    task.due_date.present? && task.due_date < Date.current && !done?(task)
  end

  # The built-in PDF fonts only know Western characters: swap anything else for "?"
  def safe(text)
    text.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?").encode("UTF-8")
  end

  # Text inside inline-formatted table cells must not contain markup characters
  def escape(text)
    text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end
end