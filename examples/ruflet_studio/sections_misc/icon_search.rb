# frozen_string_literal: true

module RufletStudio
  module SectionsMisc
    ICON_SEARCH_MAX_RESULTS = 80
    ICON_SEARCH_RESULTS_HEIGHT = 420

    def build_icon_search(page, status)
      query = ""
      summary = text(value: icon_search_summary_text(query, []), style: { size: 12 })
      copy_status = text(value: "Tap an item to copy icon name", style: { size: 12 })
      results_grid = grid_view(
        runs_count: 3,
        max_extent: 220,
        child_aspect_ratio: 2.0,
        spacing: 10,
        run_spacing: 10,
        controls: []
      )

      on_query_change = lambda do |new_query|
        query = new_query.to_s
        names = icon_search_filtered_names(query)
        page.update(summary, value: icon_search_summary_text(query, names))
        page.update(results_grid, controls: names.map { |name| icon_search_tile(page, name, copy_status) })
        page.update(copy_status, value: "Tap an item to copy icon name")
      end

      container(
        width: 760,
        content: column(
          spacing: 10,
          children: [
            status,
            text_field(
              label: "Search Material icons",
              autofocus: true,
              value: query,
              on_change: ->(e) {
                data = e.data
                value = data.is_a?(Hash) ? (data["value"] || data[:value]) : data
                on_query_change.call(value.to_s)
              }
            ),
            summary,
            copy_status,
            container(
              height: ICON_SEARCH_RESULTS_HEIGHT,
              content: results_grid
            )
          ]
        )
      )
    end

    def icon_search_tile(page, name, copy_status)
      container(
        padding: 10,
        border_radius: 8,
        on_click: ->(_e) {
          call_id = page.set_clipboard(name)
          if call_id
            page.update(copy_status, value: "Copied: #{name}")
          else
            page.update(copy_status, value: "Copy failed: clipboard service unavailable")
          end
        },
        content: row(
          spacing: 8,
          children: [
            icon(icon: Ruflet::MaterialIcons.const_get(name)),
            container(
              expand: true,
              content: text(value: name, max_lines: 1, ellipsis: true)
            )
          ]
        )
      )
    rescue NameError
      container(
        padding: 10,
        border_radius: 8,
        content: text(value: name)
      )
    end

    def icon_search_summary_text(query, names)
      total = icon_search_icon_names.size
      shown = names.size
      q = query.to_s.strip
      return "Type to search icons (#{total} available)" if q.empty?

      "Showing #{shown} results for \"#{q}\""
    end

    def icon_search_icon_names
      @icon_search_icon_names ||= Ruflet::MaterialIcons.constants(false).map(&:to_s).sort
    end

    def icon_search_filtered_names(query)
      q = query.to_s.strip.upcase
      return [] if q.empty?

      icon_search_icon_names.select { |name| name.include?(q) }.first(ICON_SEARCH_MAX_RESULTS)
    end
  end
end
