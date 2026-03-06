# frozen_string_literal: true

require "ruflet"

class IconSearchApp < Ruflet::App
  MAX_RESULTS = 80

  def initialize
    super
    @query = ""
    @summary_control = nil
    @results_grid = nil
    @copy_status_control = nil
  end

  def view(page)
    page.title = "Icon Search"
    render(page)
  end

  private

  def render(page)
    names = filtered_icon_names(@query)
    @summary_control = text(value: summary_text(names), size: 12, color: "#6c757d")
    @copy_status_control = text(value: "Tap an item to copy icon name", size: 12, color: "#6c757d")
    @results_grid = build_results_grid(names)

    page.add(
      container(
        expand: true,
        padding: 16,
        alignment: Ruflet::MainAxisAlignment::CENTER,
        content: column(
          expand: true,
          alignment: Ruflet::MainAxisAlignment::CENTER,
          horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
          spacing: 12,
          controls: [
            text_field(
              label: "Search Material icons",
              value: @query,
              autofocus: true,
              on_change: ->(e) {
                @query = event_value(e)
                update_results(page)
              }
            ),
            @summary_control,
            @copy_status_control,
            @results_grid
          ]
        )
      ),
      appbar: app_bar(
        title: text(value: "Icon Search")
      )
    )
  end

  def update_results(page)
    names = filtered_icon_names(@query)
    page.update(@summary_control, value: summary_text(names))
    page.update(@results_grid, controls: grid_items(names))
    page.update(@copy_status_control, value: "Tap an item to copy icon name", color: "#6c757d")
  end

  def build_results_grid(names)
    grid_view(
      expand: true,
      runs_count: 3,
      max_extent: 220,
      child_aspect_ratio: 2.0,
      spacing: 10,
      run_spacing: 10,
      controls: grid_items(names)
    )
  end

  def grid_items(names)
    names.map { |name| icon_tile(name) }
  end

  def icon_tile(name)
    container(
      padding: 10,
      border_radius: 8,
      on_click: ->(e) { copy_icon_name(e.page, name) },
      content: row(
        spacing: 8,
        controls: [
          icon(icon: Ruflet::MaterialIcons.const_get(name)),
          container(
            expand: true,
            content: text(value: name, max_lines: 1, overflow: "ellipsis")
          )
        ]
      )
    )
  end

  def copy_icon_name(page, name)
    copied = copy_to_clipboard(name)
    if copied
      @copy_status_control.props["value"] = "Copied: #{name}"
      @copy_status_control.props["color"] = "#2b8a3e"
    else
      @copy_status_control.props["value"] = "Copy failed on this platform for: #{name}"
      @copy_status_control.props["color"] = "#c92a2a"
    end
    page.update(@copy_status_control, value: @copy_status_control.props["value"], color: @copy_status_control.props["color"])
  end

  def copy_to_clipboard(text)
    return write_to_command("pbcopy", text) if command_available?("pbcopy")
    return write_to_command("wl-copy", text) if command_available?("wl-copy")
    return write_to_command("xclip", text, "-selection", "clipboard") if command_available?("xclip")
    return write_to_command("xsel", text, "--clipboard", "--input") if command_available?("xsel")
    return write_to_command("clip", text) if command_available?("clip")

    false
  rescue StandardError
    false
  end

  def command_available?(name)
    system("which", name, out: File::NULL, err: File::NULL)
  end

  def write_to_command(command, text, *args)
    io = IO.popen([command, *args], "w")
    io.write(text.to_s)
    io.close
    $?.success?
  rescue StandardError
    false
  end

  def event_value(event)
    data = event.data
    return data if data.is_a?(String)
    return data["value"].to_s if data.is_a?(Hash) && data["value"]

    ""
  end

  def summary_text(names)
    total = icon_names.size
    shown = names.size
    query = @query.to_s.strip
    return "Type to search icons (#{total} available)" if query.empty?

    "Showing #{shown} results for \"#{query}\""
  end

  def icon_names
    @icon_names ||= Ruflet::MaterialIcons.constants(false).map(&:to_s).sort
  end

  def filtered_icon_names(query)
    q = query.to_s.strip.upcase
    return [] if q.empty?

    icon_names.select { |name| name.include?(q) }.first(MAX_RESULTS)
  end
end

IconSearchApp.new.run
