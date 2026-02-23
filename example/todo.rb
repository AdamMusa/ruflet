require "ruby_native"

class TodoApp < RubyNative::App
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
    page.bgcolor = RubyNative::Colors.SURFACE
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

    input = page.text_field(
      value: @draft,
      hint_text: "What needs to be done?",
      width: compact ? (content_width - 24) : [content_width - 110, 560].min,
      color: RubyNative::Colors.ON_SURFACE,
      on_change: ->(e) { @draft = e.data.to_s },
      on_submit: ->(e) { add_task(e.page) }
    )

    filtered = filtered_tasks

    task_controls = if filtered.empty?
      [
        page.container(
          padding: 16,
          content: page.text(value: "No tasks", color: RubyNative::Colors.ON_SURFACE_VARIANT)
        )
      ]
      else
        filtered.map { |task| task_row(page, task) }
      end

    page.add(
      page.container(
        width: content_width,
        padding: 20,
        bgcolor: RubyNative::Colors.SURFACE_CONTAINER_LOW,
        border_radius: 12,
        content: page.column(
          spacing: 14,
          controls: [
            page.text(value: "Todo List", size: 28, weight: "w600", color: RubyNative::Colors.ON_SURFACE),
            add_row(page, input, compact),
            page.container(
              bgcolor: RubyNative::Colors.SURFACE_CONTAINER,
              border_radius: 10,
              padding: 8,
              content: page.column(spacing: 6, controls: task_controls)
            ),
            footer(page, compact)
          ]
        )
      ),
      appbar: page.app_bar(
        title: page.text(value: "Todo List", color: RubyNative::Colors.ON_PRIMARY),
        bgcolor: RubyNative::Colors.PRIMARY
      ),
      floating_action_button: page.floating_action_button(
        content: "+",
        bgcolor: RubyNative::Colors.PRIMARY,
        forground_color: "white74",
        on_click: ->(e) { add_task(e.page) }
      )
    )
  end

  def task_row(page, task)
    label = task[:done] ? "✓ #{task[:text]}" : task[:text]

    page.row(
      alignment: "spaceBetween",
      vertical_alignment: "center",
      controls: [
        page.checkbox(
          value: task[:done],
          label: label,
          expand: true,
          on_change: ->(e) { toggle_task(task[:id], e.page) }
        ),
        page.text_button(
          text: "Delete",
          on_click: ->(e) { delete_task(task[:id], e.page) }
        )
      ]
    )
  end

  def add_row(page, input, compact)
    add_button = page.elevated_button(
      text: "Add",
      bgcolor: RubyNative::Colors.PRIMARY,
      color: RubyNative::Colors.ON_PRIMARY,
      on_click: ->(e) { add_task(e.page) }
    )

    if compact
      page.column(spacing: 10, controls: [input, add_button])
    else
      page.row(spacing: 10, controls: [input, add_button])
    end
  end

  def footer(page, compact)
    active_count = @tasks.count { |task| !task[:done] }

    counter = page.text(
      value: "#{active_count} item#{active_count == 1 ? "" : "s"} left",
      color: RubyNative::Colors.ON_SURFACE_VARIANT
    )
    filters = page.row(
      spacing: 6,
      controls: FILTERS.map { |name| filter_button(page, name) }
    )
    clear_btn = page.text_button(
      text: "Clear completed",
      color: RubyNative::Colors.PRIMARY,
      on_click: ->(e) { clear_completed(e.page) }
    )

    if compact
      page.column(spacing: 8, controls: [counter, filters, clear_btn])
    else
      page.row(
        alignment: "spaceBetween",
        vertical_alignment: "center",
        controls: [counter, filters, clear_btn]
      )
    end
  end

  def filter_button(page, name)
    selected = (@filter == name)
    if selected
      page.filled_button(
        text: name.capitalize,
        bgcolor: RubyNative::Colors.PRIMARY,
        color: RubyNative::Colors.ON_PRIMARY,
        on_click: ->(e) { set_filter(name, e.page) }
      )
    else
      page.text_button(
        text: name.capitalize,
        color: RubyNative::Colors.PRIMARY,
        on_click: ->(e) { set_filter(name, e.page) }
      )
    end
  end

  def add_task(page)
    text = @draft.to_s.strip
    return if text.empty?

    @tasks << { id: @next_id, text: text, done: false }
    @next_id += 1
    @draft = ""
    render(page)
  end

  def toggle_task(task_id, page)
    task = @tasks.find { |t| t[:id] == task_id }
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
end

TodoApp.new.run
