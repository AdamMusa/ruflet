# frozen_string_literal: true

module RufletStudio
  module SectionsMisc
    def build_charts(page, status)
      bar_chart = bar_chart(
        width: 320,
        height: 180,
        max_y: 110,
        border: { width: 1, color: color_divider(page) },
        horizontal_grid_lines: { color: color_divider(page), width: 1, dash_pattern: [3, 3] },
        tooltip: nil,
        left_axis: chart_axis(label_size: 40, title: text(value: "Fruit supply"), title_size: 40),
        right_axis: chart_axis(show_labels: false),
        bottom_axis: chart_axis(
          label_size: 40,
          labels: [
            chart_axis_label(value: 0, label: container(content: text(value: "Apple"), padding: 10)),
            chart_axis_label(value: 1, label: container(content: text(value: "Blueberry"), padding: 10)),
            chart_axis_label(value: 2, label: container(content: text(value: "Cherry"), padding: 10)),
            chart_axis_label(value: 3, label: container(content: text(value: "Orange"), padding: 10))
          ]
        ),
        groups: [
          bar_chart_group(x: 0, rods: [bar_chart_rod(from_y: 0, to_y: 40, width: 40, color: "#69db7c", border_radius: 0)]),
          bar_chart_group(x: 1, rods: [bar_chart_rod(from_y: 0, to_y: 100, width: 40, color: "#4dabf7", border_radius: 0)]),
          bar_chart_group(x: 2, rods: [bar_chart_rod(from_y: 0, to_y: 30, width: 40, color: "#ff6b6b", border_radius: 0)]),
          bar_chart_group(x: 3, rods: [bar_chart_rod(from_y: 0, to_y: 60, width: 40, color: "#ffa94d", border_radius: 0)])
        ]
      )

      line_chart = line_chart(
        data_series: [
          line_chart_data(points: [
            line_chart_data_point(x: 1, y: 1),
            line_chart_data_point(x: 3, y: 1.5),
            line_chart_data_point(x: 5, y: 1.4),
            line_chart_data_point(x: 7, y: 3.4)
          ], stroke_width: 4, color: "#51cf66", curved: true, rounded_stroke_cap: true),
          line_chart_data(points: [
            line_chart_data_point(x: 1, y: 1),
            line_chart_data_point(x: 3, y: 2.8),
            line_chart_data_point(x: 7, y: 1.2),
            line_chart_data_point(x: 10, y: 2.8)
          ], stroke_width: 4, color: "#f06595", curved: true, rounded_stroke_cap: true)
        ],
        min_y: 0,
        max_y: 4,
        min_x: 0,
        max_x: 14,
        interactive: true,
        width: 320,
        height: 180,
        tooltip: nil,
        on_event: ->(e) { page.update(status, value: "Line chart event: #{e.data}") }
      )

      pie_chart = pie_chart(
        width: 220,
        height: 220,
        sections_space: 0,
        center_space_radius: 0,
        sections: [
          pie_chart_section(value: 40, title: "40%", color: "#4dabf7", radius: 100),
          pie_chart_section(value: 30, title: "30%", color: "#ffd43b", radius: 100),
          pie_chart_section(value: 15, title: "15%", color: "#845ef7", radius: 100),
          pie_chart_section(value: 15, title: "15%", color: "#51cf66", radius: 100)
        ],
        on_event: ->(e) { page.update(status, value: "Pie chart event: #{e.data}") }
      )

      candlestick_chart = candlestick_chart(
        width: 320,
        height: 180,
        min_x: -0.5,
        max_x: 6.5,
        min_y: 22,
        max_y: 36,
        spots: [
          candlestick_chart_spot(x: 0, open: 24.8, high: 28.6, low: 23.9, close: 27.2, selected: true),
          candlestick_chart_spot(x: 1, open: 27.2, high: 30.1, low: 25.8, close: 28.4)
        ],
        tooltip: nil,
        on_event: ->(e) { page.update(status, value: "Candlestick event: #{e.data}") }
      )

      radar_chart = radar_chart(
        width: 300,
        height: 180,
        titles: [
          radar_chart_title(text: "macOS"),
          radar_chart_title(text: "Linux"),
          radar_chart_title(text: "Windows")
        ],
        data_sets: [
          radar_data_set(entries: [
            radar_data_set_entry(value: 300),
            radar_data_set_entry(value: 50),
            radar_data_set_entry(value: 250)
          ])
        ],
        on_event: ->(e) { page.update(status, value: "Radar event: #{e.data}") }
      )

      scatter_chart = scatter_chart(
        width: 300,
        height: 180,
        min_x: 0,
        max_x: 50,
        min_y: 0,
        max_y: 50,
        left_axis: chart_axis(show_labels: false),
        right_axis: chart_axis(show_labels: false),
        top_axis: chart_axis(show_labels: false),
        bottom_axis: chart_axis(show_labels: false),
        on_event: ->(e) { page.update(status, value: "Scatter event: #{e.data}") },
        spots: [
          scatter_chart_spot(x: 10, y: 10, radius: 6, color: "#339af0"),
          scatter_chart_spot(x: 20, y: 25, radius: 10, color: "#ff922b"),
          scatter_chart_spot(x: 35, y: 40, radius: 8, color: "#51cf66")
        ]
      )

      column(
        spacing: 12,
        tight: true,
        children: [
          text(value: "BarChart", style: { size: 14, weight: "w600" }),
          bar_chart,
          text(value: "LineChart", style: { size: 14, weight: "w600" }),
          line_chart,
          text(value: "PieChart", style: { size: 14, weight: "w600" }),
          pie_chart,
          text(value: "CandlestickChart", style: { size: 14, weight: "w600" }),
          candlestick_chart,
          text(value: "RadarChart", style: { size: 14, weight: "w600" }),
          radar_chart,
          text(value: "ScatterChart", style: { size: 14, weight: "w600" }),
          scatter_chart
        ]
      )
    end
  end
end
