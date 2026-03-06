# frozen_string_literal: true

require "ruflet"

class IconSearchApp < Ruflet::App
  MAX_RESULTS = 80

  def initialize
    super
    @query = ""
    @summary_control = nil
    @results_grid = nil
  end

  def view(page)
    page.title = "Icon Search"
    render(page)
  end

  private

  def render(page)
    names = filtered_icon_names(@query)
    @summary_control = text(value: summary_text(names), size: 12, color: "#6c757d")
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
      bgcolor: "#f4f5f7",
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
