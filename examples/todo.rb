require "ruflet"

class TodoApp < Ruflet::App
  FILTERS = %w[all active completed].freeze

  def initialize
    super
    @tasks = []
    @next_id = 1
    @filter = "all"
    @draft = ""
  end

  def view(page)
    page.title = "Todo"
    page.bgcolor = Ruflet::Colors.SURFACE
    page.vertical_alignment = "center"
    page.horizontal_alignment = "center"

    render(page)
  end

  private

  def render(page)
    viewport_width = page.client_details["width"].to_f
    viewport_width = 390.0 if viewport_width <= 0
    compact = viewport_width <= 600
    content_width = [[viewport_width - 24, 300].max, 720].min

    input = text_field(
      value: @draft,
      hint_text: "What needs to be done?",
      width: compact ? (content_width - 24) : [content_width - 110, 560].min,
      color: Ruflet::Colors.ON_SURFACE,
      on_change: ->(e) { @draft = e.data.to_s },
      on_submit: ->(e) { add_task(e.page) }
    )

    task_controls = if filtered_tasks.empty?
      [
        container(
          padding: 16,
          content: text(value: "No tasks", style: { color: Ruflet::Colors.ON_SURFACE_VARIANT })
        )
      ]
    else
      filtered_tasks.map { |task| task_row(page, task) }
    end

    page.add(
      container(
        width: content_width,
        padding: 20,
        bgcolor: Ruflet::Colors.SURFACE_CONTAINER_LOW,
        border_radius: 12,
        content: column(
          spacing: 14,
          children: [
            text(value: "Todo List", style: { size: 28, weight: "w600", color: Ruflet::Colors.ON_SURFACE }),
            add_row(page, input, compact),
            container(
              bgcolor: Ruflet::Colors.SURFACE_CONTAINER,
              border_radius: 10,
              padding: 8,
              content: column(spacing: 6, children: task_controls)
            ),
            footer(page, compact)
          ]
        )
      ),
      appbar: app_bar(
        title: text(value: "Todo List", style: { color: Ruflet::Colors.ON_PRIMARY }),
        bgcolor: Ruflet::Colors.PRIMARY
      ),
      floating_action_button: fab(
        content: text("+"),
        bgcolor: Ruflet::Colors.PRIMARY,
        color: "white74",
        on_click: ->(e) { add_task(e.page) }
      )
    )
  end

  def filtered_tasks
    case @filter
    when "active"
      @tasks.reject { |task| task[:done] }
    when "completed"
      @tasks.select { |task| task[:done] }
    else
      @tasks
    end
  end

  def task_row(page, task)
    label = task[:done] ? "✓ #{task[:text]}" : task[:text]

    row(
      alignment: "spaceBetween",
      vertical_alignment: "center",
      children: [
        checkbox(
          value: task[:done],
          label: label,
          expand: true,
          on_change: ->(e) { toggle_task(task[:id], e.page) }
        ),
        text_button(
          content: text("Delete"),
          on_click: ->(e) { delete_task(task[:id], e.page) }
        )
      ]
    )
  end

  def add_row(page, input, compact)
    add_button = elevated_button(
      content: text("Add"),
      bgcolor: Ruflet::Colors.PRIMARY,
      color: Ruflet::Colors.ON_PRIMARY,
      on_click: ->(e) { add_task(e.page) }
    )

    if compact
      column(spacing: 10, children: [input, add_button])
    else
      row(spacing: 10, children: [input, add_button])
    end
  end

  def footer(page, compact)
    active_count = @tasks.count { |task| !task[:done] }
    counter = text(
      value: "#{active_count} item#{active_count == 1 ? "" : "s"} left",
      style: { color: Ruflet::Colors.ON_SURFACE_VARIANT }
    )
    filter_controls = row(
      spacing: 6,
      children: FILTERS.map { |name| filter_button(page, name) }
    )
    clear_button = text_button(
      content: text("Clear completed"),
      on_click: ->(e) { clear_completed(e.page) }
    )

    if compact
      column(spacing: 8, children: [counter, filter_controls, clear_button])
    else
      row(
        alignment: "spaceBetween",
        vertical_alignment: "center",
        children: [counter, filter_controls, clear_button]
      )
    end
  end

  def filter_button(page, name)
    selected = (@filter == name)
    if selected
      filled_button(
        content: text(name.capitalize),
        bgcolor: Ruflet::Colors.PRIMARY,
        color: Ruflet::Colors.ON_PRIMARY,
        on_click: ->(e) { set_filter(name, e.page) }
      )
    else
      text_button(
        content: text(name.capitalize),
        color: Ruflet::Colors.PRIMARY,
        on_click: ->(e) { set_filter(name, e.page) }
      )
    end
  end

  def add_task(page)
    task_text = @draft.to_s.strip
    return if task_text.empty?

    @tasks << { id: @next_id, text: task_text, done: false }
    @next_id += 1
    @draft = ""
    render(page)
  end

  def toggle_task(task_id, page)
    task = @tasks.find { |item| item[:id] == task_id }
    return unless task

    task[:done] = !task[:done]
    render(page)
  end

  def delete_task(task_id, page)
    @tasks.reject! { |task| task[:id] == task_id }
    render(page)
  end

  def set_filter(name, page)
    @filter = name
    render(page)
  end

  def clear_completed(page)
    @tasks.reject! { |task| task[:done] }
    render(page)
  end
end

TodoApp.new.run
