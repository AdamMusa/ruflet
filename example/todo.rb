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
    page.bgcolor = "#F5F5F5"
    page.vertical_alignment = "start"
    page.horizontal_alignment = "center"

    render(page)
  end

  private

  def render(page)
    input = page.text_field(
      value: @draft,
      hint_text: "What needs to be done?",
      width: 560,
      on_change: ->(e) { @draft = e.data.to_s },
      on_submit: ->(e) { add_task(e.page) }
    )

    filtered = filtered_tasks

    task_controls = if filtered.empty?
                      [
                        page.container(
                          padding: 16,
                          content: page.text(value: "No tasks", color: "#666666")
                        )
                      ]
                    else
                      filtered.map { |task| task_row(page, task) }
                    end

    page.add(
      page.container(
        width: 720,
        padding: 20,
        content: page.column(
          spacing: 14,
          controls: [
            page.text(value: "Todo List", size: 28, weight: "w600"),
            page.row(
              spacing: 10,
              controls: [
                input,
                page.elevated_button(text: "Add", on_click: ->(e) { add_task(e.page) })
              ]
            ),
            page.container(
              bgcolor: "#FFFFFF",
              border_radius: 10,
              padding: 8,
              content: page.column(spacing: 6, controls: task_controls)
            ),
            footer(page)
          ]
        )
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

  def footer(page)
    active_count = @tasks.count { |task| !task[:done] }

    page.row(
      alignment: "spaceBetween",
      vertical_alignment: "center",
      controls: [
        page.text(value: "#{active_count} item#{active_count == 1 ? "" : "s"} left"),
        page.row(
          spacing: 6,
          controls: FILTERS.map { |name| filter_button(page, name) }
        ),
        page.text_button(text: "Clear completed", on_click: ->(e) { clear_completed(e.page) })
      ]
    )
  end

  def filter_button(page, name)
    selected = (@filter == name)
    if selected
      page.filled_button(
        text: name.capitalize,
        on_click: ->(e) { set_filter(name, e.page) }
      )
    else
      page.text_button(
        text: name.capitalize,
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
