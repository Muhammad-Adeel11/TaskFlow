require "prawn"
require "prawn/table"

class ProjectReportPdf
  BLACK  = "111111".freeze
  TEXT   = "333333".freeze
  MUTED  = "8A8A8A".freeze
  BORDER = "DDDDDD".freeze

  # Statuses that count as finished (adjust to your enum values)
  DONE_STATUSES = %w[completed done].freeze

  def initialize(project, tasks)
    @project = project
    @tasks   = tasks.to_a
    @pdf     = Prawn::Document.new(page_size: "A4", margin: [60, 50, 70, 50])
    @pdf.font "Helvetica"
  end

  def render
    header
    title_block
    overview
    tasks_section
    footer
    @pdf.render
  end

  private

  # ---------- Header: wordmark left, report info right, rule below ----------
  def header
    top   = @pdf.cursor
    width = @pdf.bounds.width

    @pdf.fill_color BLACK
    @pdf.text_box "TASKFLOW", at: [0, top], width: 250,
                  size: 15, style: :bold, character_spacing: 3

    @pdf.text_box "PROJECT REPORT", at: [width - 200, top], width: 200,
                  size: 8, style: :bold, align: :right, character_spacing: 1.5

    @pdf.fill_color MUTED
    @pdf.text_box Time.current.strftime("%d %B %Y"), at: [width - 200, top - 13],
                  width: 200, size: 8, align: :right

    @pdf.move_cursor_to top - 34
    @pdf.stroke_color BLACK
    @pdf.line_width 1.5
    @pdf.stroke_horizontal_rule
    @pdf.line_width 1
    @pdf.move_down 32
  end

  # ---------- Project name + description ----------
  def title_block
    @pdf.fill_color MUTED
    @pdf.text "PROJECT", size: 7.5, style: :bold, character_spacing: 1.5
    @pdf.move_down 6

    @pdf.fill_color BLACK
    @pdf.text @project.name.to_s, size: 26, style: :bold, leading: 2
    @pdf.move_down 8

    @pdf.fill_color TEXT
    @pdf.text (@project.description.presence || "No description provided."),
              size: 10, leading: 4
    @pdf.move_down 28
  end

  # ---------- Key figures + progress bar ----------
  def overview
    total   = @tasks.size
    done    = @tasks.count { |t| done?(t) }
    overdue = @tasks.count { |t| overdue?(t) }
    percent = total.zero? ? 0 : (done * 100.0 / total).round

    stats = [
      ["Total tasks", total],
      ["Completed",   done],
      ["Open",        total - done],
      ["Overdue",     overdue]
    ]

    col_w = @pdf.bounds.width / stats.size
    top   = @pdf.cursor

    stats.each_with_index do |(label, value), i|
      x   = i * col_w
      pad = i.zero? ? 0 : 16

      @pdf.fill_color BLACK
      @pdf.text_box value.to_s, at: [x + pad, top], width: col_w - pad,
                    size: 26, style: :bold

      @pdf.fill_color MUTED
      @pdf.text_box label.upcase, at: [x + pad, top - 34], width: col_w - pad,
                    size: 7, style: :bold, character_spacing: 1

      next if i.zero?
      @pdf.stroke_color BORDER
      @pdf.stroke_vertical_line top - 2, top - 46, at: x
    end

    @pdf.move_cursor_to top - 66

    # Progress bar (grayscale)
    y     = @pdf.cursor
    width = @pdf.bounds.width
    @pdf.fill_color BORDER
    @pdf.fill_rectangle [0, y], width, 4
    @pdf.fill_color BLACK
    @pdf.fill_rectangle [0, y], width * percent / 100.0, 4

    @pdf.move_down 12
    @pdf.fill_color MUTED
    @pdf.text "#{percent}% complete", size: 8
    @pdf.move_down 30
  end

  # ---------- Task table ----------
  def tasks_section
    @pdf.fill_color BLACK
    @pdf.text "Tasks", size: 14, style: :bold
    @pdf.move_down 12

    if @tasks.empty?
      @pdf.fill_color MUTED
      @pdf.text "This project has no tasks yet.", size: 10
      return
    end

    rows = [%w[No. Task Assignee Due Status]]

    @tasks.each_with_index do |task, i|
      late = overdue?(task)
      due  = task.due_date ? task.due_date.strftime("%d %b %Y") : "-"
      due  = "#{due}\nOVERDUE" if late

      rows << [
        format("%02d", i + 1),
        { content: task.title.to_s, font_style: :bold, text_color: BLACK },
        task.user&.name || "Unassigned",
        { content: due, font_style: late ? :bold : :normal,
          text_color: late ? BLACK : TEXT },
        { content: task.status.to_s.humanize.upcase, size: 7.5,
          font_style: :bold,
          text_color: done?(task) ? MUTED : BLACK }
      ]
    end

    @pdf.table(rows,
               header: true,
               width: @pdf.bounds.width,
               column_widths: { 0 => 32, 2 => 105, 3 => 80, 4 => 78 },
               cell_style: {
                 size: 9, text_color: TEXT, padding: [10, 6],
                 borders: [:bottom], border_width: 0.5, border_color: BORDER
               }) do
      row(0).font_style   = :bold
      row(0).size         = 7
      row(0).text_color   = MUTED
      row(0).padding      = [0, 6, 8, 6]
      row(0).border_width = 1.5
      row(0).border_color = BLACK
      column(0).text_color = MUTED
      column(0).size       = 8
    end
  end

  # ---------- Footer on every page ----------
  def footer
    @pdf.repeat(:all, dynamic: true) do
      width = @pdf.bounds.width

      @pdf.stroke_color BORDER
      @pdf.line_width 0.5
      @pdf.stroke_horizontal_line 0, width, at: -14

      @pdf.fill_color MUTED
      @pdf.text_box "TaskFlow  /  #{@project.name}",
                    at: [0, -22], width: width - 100, size: 7.5
      @pdf.text_box "Page #{@pdf.page_number} of #{@pdf.page_count}",
                    at: [width - 100, -22], width: 100, size: 7.5, align: :right
    end
  end

  def done?(task)
    DONE_STATUSES.include?(task.status.to_s)
  end

  def overdue?(task)
    task.due_date.present? && task.due_date < Date.current && !done?(task)
  end
end