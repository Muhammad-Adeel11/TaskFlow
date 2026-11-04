require "caxlsx"

# Builds the project report as an Excel workbook (two sheets: Summary, Tasks).
# Usage: ProjectReportXlsx.new(project, tasks, generated_by: current_user).render
class ProjectReportXlsx
  CONTENT_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet".freeze

  # ---------- palette (matches the TaskFlow app and the PDF) ----------
  INK    = "0E1020".freeze
  TEXT   = "2A2E45".freeze
  MUTED  = "6B7090".freeze
  BORDER = "E4E6F0".freeze
  SOFT   = "F6F7FB".freeze
  ACCENT = "4F46E5".freeze
  DANGER = "BE123C".freeze

  STATUSES = {
    "pending"     => { label: "Pending",     text: "9A5B06", fill: "FDF3DC", bar: "E0A93B" },
    "in_progress" => { label: "In progress", text: "1D4ED8", fill: "E4EBFF", bar: "5B7CFA" },
    "completed"   => { label: "Completed",   text: "0F7A43", fill: "DDF5EA", bar: "2FAE7B" }
  }.freeze

  DONE_STATUSES = %w[completed done].freeze

  def initialize(project, tasks, generated_by: nil)
    @project      = project
    @tasks        = tasks.to_a
    @generated_by = generated_by
  end

  def render
    @package = Axlsx::Package.new
    @book    = @package.workbook
    @book.use_shared_strings = true

    build_styles
    summary_sheet
    tasks_sheet

    @package.to_stream.read
  end

  private

  # ================= Summary sheet =================
  def summary_sheet
    sheet = @book.add_worksheet(name: "Summary", tab_color: ACCENT)
    sheet.column_widths(*([15] * 8))
    safely { sheet.sheet_view.show_grid_lines = false }

    total = @tasks.size
    done  = count_status("completed")
    share = ->(count) { total.zero? ? 0 : (count.to_f / total).round(3) }

    # --- dark title band ---
    row sheet, ["TASKFLOW  /  PROJECT REPORT", *blank(5), Time.current.strftime("%d %B %Y"), nil],
        %i[band_small band_small band_small band_small band_small band_small band_right band_right], height: 30
    sheet.merge_cells "A1:F1"
    sheet.merge_cells "G1:H1"

    row sheet, [clean(@project.name), *blank(7)], [:band_title] * 8, height: 50
    sheet.merge_cells "A2:H2"

    description = clean(@project.description.presence || "No description provided.").squish
    row sheet, [description, *blank(7)], [:band_desc] * 8, height: 52
    sheet.merge_cells "A3:H3"

    spacer sheet, 12

    # --- who / when ---
    labels = ["GENERATED", "PREPARED BY", "TEAM MEMBERS", "PROJECT CREATED"]
    values = [
      Time.current.strftime("%d %b %Y, %H:%M"),
      clean(@generated_by&.name || "TaskFlow"),
      @project.memberships.count.to_s,
      @project.created_at.strftime("%d %b %Y")
    ]
    pair_row sheet, labels, :label, height: 18
    pair_row sheet, values, :value, height: 24

    spacer sheet, 14

    # --- four key figures ---
    kpis = [
      ["TOTAL TASKS", total,                         :kpi_total],
      ["COMPLETED",   done,                          :kpi_done],
      ["IN PROGRESS", count_status("in_progress"),   :kpi_progress],
      ["OVERDUE",     @tasks.count { |t| overdue?(t) }, :kpi_overdue]
    ]
    pair_row sheet, kpis.map { |k| k[0] }, :kpi_label, height: 22
    pair_row sheet, kpis.map { |k| k[1] }, nil, styles: kpis.map { |k| k[2] }, height: 44

    spacer sheet, 16

    # --- status breakdown (table + chart) ---
    section sheet, "Status breakdown"
    header_row = sheet.rows.size + 1
    row sheet, ["Status", nil, "Tasks", "Share", nil, nil, nil, nil],
        %i[th th th_right th_right none none none none], height: 24
    sheet.merge_cells "A#{header_row}:B#{header_row}"

    first_status_row = sheet.rows.size + 1
    %w[pending in_progress completed].each do |status|
      count = count_status(status)
      row sheet, [STATUSES[status][:label], nil, count, share.call(count), nil, nil, nil, nil],
          [:"status_#{status}", :"status_#{status}", :td_number, :td_percent, :none, :none, :none, :none],
          height: 24
      sheet.merge_cells "A#{sheet.rows.size}:B#{sheet.rows.size}"
    end
    last_status_row = sheet.rows.size

    row sheet, ["Total", nil, total, total.zero? ? 0 : 1, nil, nil, nil, nil],
        %i[total_label total_label total_number total_percent none none none none], height: 24
    sheet.merge_cells "A#{sheet.rows.size}:B#{sheet.rows.size}"

    status_chart(sheet, first_status_row, last_status_row)

    # leave room for the chart beside the table
    (sheet.rows.size..22).each { spacer sheet, 22 }

    # --- workload ---
    workload_table(sheet)

    page_setup(sheet, landscape: false)
  end

  def status_chart(sheet, first_row, last_row)
    safely do
      sheet.add_chart(Axlsx::BarChart,
                      title: "Tasks by status",
                      start_at: [4, first_row - 2],
                      end_at: [8, last_row + 3],
                      bar_dir: :col,
                      grouping: :clustered,
                      show_legend: false) do |chart|
        chart.add_series data: sheet["C#{first_row}:C#{last_row}"],
                         labels: sheet["A#{first_row}:A#{last_row}"],
                         title: "Tasks",
                         colors: %w[E0A93B 5B7CFA 2FAE7B]
      end
    end
  end

  def workload_table(sheet)
    section sheet, "Workload by member"

    row sheet, ["Member", nil, nil, "Assigned", "Completed", "In progress", "Pending", "Overdue"],
        %i[th th th th_right th_right th_right th_right th_right], height: 24
    sheet.merge_cells "A#{sheet.rows.size}:C#{sheet.rows.size}"

    if @tasks.empty?
      row sheet, ["No tasks yet.", *blank(7)], [:td_text] + [:td_text] * 7, height: 24
      sheet.merge_cells "A#{sheet.rows.size}:H#{sheet.rows.size}"
      return
    end

    grouped = @tasks.group_by { |t| t.user&.name || "Unassigned" }
    ordered = grouped.sort_by { |name, list| [-list.size, name.to_s.downcase] }

    ordered.each_with_index do |(name, list), i|
      zebra = i.odd?
      late  = list.count { |t| overdue?(t) }

      row sheet,
          [clean(name), nil, nil, list.size,
           list.count { |t| t.status.to_s == "completed" },
           list.count { |t| t.status.to_s == "in_progress" },
           list.count { |t| t.status.to_s == "pending" },
           late],
          [zebra ? :td_text_alt : :td_text, zebra ? :td_text_alt : :td_text, zebra ? :td_text_alt : :td_text,
           *([zebra ? :td_number_alt : :td_number] * 4),
           late.positive? ? :td_late : (zebra ? :td_number_alt : :td_number)],
          height: 24
      sheet.merge_cells "A#{sheet.rows.size}:C#{sheet.rows.size}"
    end
  end

  # ================= Tasks sheet =================
  def tasks_sheet
    sheet = @book.add_worksheet(name: "Tasks", tab_color: "5B7CFA")
    sheet.column_widths 7, 38, 54, 22, 14, 15, 22, 14
    safely { sheet.sheet_view.show_grid_lines = false }

    row sheet, ["#{clean(@project.name)}  /  Tasks", *blank(7)], [:band_title_small] * 8, height: 38
    sheet.merge_cells "A1:H1"

    note = "#{@tasks.size} #{@tasks.size == 1 ? 'task' : 'tasks'}  /  generated #{Time.current.strftime('%d %b %Y, %H:%M')}"
    row sheet, [note, *blank(7)], [:band_small] * 8, height: 22
    sheet.merge_cells "A2:H2"

    spacer sheet, 10

    header = sheet.rows.size + 1
    row sheet, ["No.", "Task", "Description", "Assignee", "Due date", "Status", "Timing", "Created"],
        %i[th_center th th th th_center th_center th th_center], height: 26

    @tasks.each_with_index do |task, i|
      zebra  = i.odd?
      status = STATUSES.fetch(task.status.to_s, STATUSES["pending"])
      late   = overdue?(task)

      row sheet,
          [i + 1,
           clean(task.title),
           clean(task.description.to_s).squish.presence || "-",
           clean(task.user&.name || "Unassigned"),
           task.due_date,
           status[:label],
           timing(task),
           task.created_at.to_date],
          [zebra ? :td_center_alt : :td_center,
           zebra ? :td_bold_alt : :td_bold,
           zebra ? :td_wrap_alt : :td_wrap,
           zebra ? :td_text_alt : :td_text,
           zebra ? :td_date_alt : :td_date,
           :"status_#{STATUSES.key(status)}",
           late ? :td_late_text : (zebra ? :td_text_alt : :td_text),
           zebra ? :td_date_alt : :td_date]
    end

    last = sheet.rows.size

    if @tasks.empty?
      row sheet, ["This project has no tasks yet.", *blank(7)], [:td_text] * 8, height: 28
      sheet.merge_cells "A#{sheet.rows.size}:H#{sheet.rows.size}"
      last = sheet.rows.size
    end

    # filter buttons on the header and a frozen header row
    safely { sheet.auto_filter = "A#{header}:H#{last}" }
    safely do
      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = "A#{header + 1}"
        pane.state         = :frozen
        pane.y_split       = header
        pane.x_split       = 0
        pane.active_pane   = :bottom_left
      end
    end

    page_setup(sheet, landscape: true)
  end

  # ================= styles =================
  def build_styles
    @s = {}

    base = { font_name: "Calibri", sz: 10, fg_color: argb(TEXT),
             alignment: { vertical: :center } }
    line = { style: :thin, color: argb(BORDER), edges: [:bottom] }
    left = ->(opts = {}) { { horizontal: :left, vertical: :center, indent: 1 }.merge(opts) }

    add = lambda do |name, opts|
      @s[name] = @book.styles.add_style(base.merge(opts))
    end

    # dark band
    add.call :band_small,       bg_color: argb(INK), fg_color: argb("A5B4FC"), b: true, sz: 9,  alignment: left.call
    add.call :band_right,       bg_color: argb(INK), fg_color: argb("A3A8C0"), sz: 9,           alignment: left.call(horizontal: :right)
    add.call :band_title,       bg_color: argb(INK), fg_color: argb("FFFFFF"), b: true, sz: 26, alignment: left.call
    add.call :band_title_small, bg_color: argb(INK), fg_color: argb("FFFFFF"), b: true, sz: 16, alignment: left.call
    add.call :band_desc,        bg_color: argb(INK), fg_color: argb("C7CBE0"), sz: 10,          alignment: left.call(wrap_text: true, vertical: :top)

    # summary: labels, values, key figures
    add.call :label,       fg_color: argb(MUTED), b: true, sz: 8,  alignment: left.call
    add.call :value,       fg_color: argb(INK),   b: true, sz: 12, alignment: left.call
    add.call :kpi_label,   bg_color: argb(SOFT),  fg_color: argb(MUTED), b: true, sz: 8,
                           alignment: left.call, border: { style: :thick, color: argb("FFFFFF"), edges: %i[left right] }
    {
      kpi_total:    INK,
      kpi_done:     STATUSES["completed"][:text],
      kpi_progress: STATUSES["in_progress"][:text],
      kpi_overdue:  DANGER
    }.each do |name, color|
      add.call name, bg_color: argb(SOFT), fg_color: argb(color), b: true, sz: 26,
                     alignment: left.call, border: { style: :thick, color: argb("FFFFFF"), edges: %i[left right] }
    end

    add.call :section, fg_color: argb(INK), b: true, sz: 14, alignment: left.call(indent: 0),
                       border: { style: :medium, color: argb(ACCENT), edges: [:bottom] }

    # table header
    th = { bg_color: argb(INK), fg_color: argb("FFFFFF"), b: true, sz: 9 }
    add.call :th,        th.merge(alignment: left.call)
    add.call :th_center, th.merge(alignment: { horizontal: :center, vertical: :center })
    add.call :th_right,  th.merge(alignment: left.call(horizontal: :right))

    # table body, plain and zebra
    { "" => "FFFFFF", "_alt" => SOFT }.each do |suffix, fill|
      body = { bg_color: argb(fill), border: line }
      add.call :"td_text#{suffix}",   body.merge(alignment: left.call)
      add.call :"td_bold#{suffix}",   body.merge(b: true, fg_color: argb(INK), alignment: left.call(wrap_text: true))
      add.call :"td_wrap#{suffix}",   body.merge(fg_color: argb(MUTED), alignment: left.call(wrap_text: true))
      add.call :"td_center#{suffix}", body.merge(fg_color: argb("A3A8C0"), alignment: { horizontal: :center, vertical: :center })
      add.call :"td_date#{suffix}",   body.merge(format_code: "dd mmm yyyy", alignment: { horizontal: :center, vertical: :center })
      add.call :"td_number#{suffix}", body.merge(alignment: left.call(horizontal: :right))
    end
    add.call :td_percent,    bg_color: argb("FFFFFF"), border: line, format_code: "0%", alignment: left.call(horizontal: :right)
    add.call :td_late,       bg_color: argb("FFFFFF"), border: line, fg_color: argb(DANGER), b: true, alignment: left.call(horizontal: :right)
    add.call :td_late_text,  bg_color: argb("FFFFFF"), border: line, fg_color: argb(DANGER), b: true, alignment: left.call

    # status badges (soft tinted cell, coloured bold text)
    STATUSES.each do |key, info|
      add.call :"status_#{key}", bg_color: argb(info[:fill]), fg_color: argb(info[:text]), b: true, sz: 9,
                                 alignment: { horizontal: :center, vertical: :center },
                                 border: { style: :thin, color: argb("FFFFFF"), edges: %i[top bottom] }
    end

    # totals
    top = { style: :thin, color: argb(INK), edges: [:top] }
    add.call :total_label,   b: true, fg_color: argb(INK), border: top, alignment: left.call
    add.call :total_number,  b: true, fg_color: argb(INK), border: top, alignment: left.call(horizontal: :right)
    add.call :total_percent, b: true, fg_color: argb(INK), border: top, format_code: "0%", alignment: left.call(horizontal: :right)

    @s[:none] = nil
  end

  # ================= helpers =================
  # One row. `names` lists a style per cell; strings are always stored as text.
  def row(sheet, values, names, height: nil)
    styles = names.map { |n| n ? @s[n] : nil }
    types  = values.map { |v| v.is_a?(String) ? :string : nil }

    options = { style: styles, types: types }
    options[:height] = height if height
    sheet.add_row(values, options)
  end

  # Four label/value pairs, each spanning two columns
  def pair_row(sheet, values, name, styles: nil, height: nil)
    cells = values.flat_map { |v| [v, nil] }
    names = values.each_index.flat_map { |i| [styles ? styles[i] : name] * 2 }

    row sheet, cells, names, height: height

    r = sheet.rows.size
    4.times { |i| sheet.merge_cells "#{('A'.ord + i * 2).chr}#{r}:#{('A'.ord + i * 2 + 1).chr}#{r}" }
  end

  def section(sheet, text)
    row sheet, [text, *blank(7)], [:section] * 8, height: 28
  end

  def spacer(sheet, height)
    sheet.add_row [], height: height
  end

  def blank(count)
    Array.new(count)
  end

  def page_setup(sheet, landscape:)
    safely do
      sheet.page_setup.set(orientation: landscape ? :landscape : :portrait, paper_size: 9)
      sheet.page_setup.fit_to(width: 1, height: 0)
      sheet.print_options.horizontal_centered = true
      sheet.header_footer.odd_footer = "&LTaskFlow  /  #{@project.name.to_s.delete('&')}&RPage &P of &N"
    end
  end

  # Decorations must never stop the download
  def safely
    yield
  rescue StandardError => e
    Rails.logger.warn("[ProjectReportXlsx] skipped a decoration: #{e.class}: #{e.message}")
  end

  def argb(hex)
    "FF#{hex}"
  end

  # Excel limits and stray control characters
  def clean(text)
    text.to_s.gsub(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/, "").slice(0, 2000)
  end

  def timing(task)
    return "No due date" if task.due_date.nil?
    return "Done" if done?(task)

    days = (task.due_date - Date.current).to_i
    if days.negative?
      "Overdue by #{-days} day#{'s' unless days == -1}"
    elsif days.zero?
      "Due today"
    else
      "In #{days} day#{'s' unless days == 1}"
    end
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
end