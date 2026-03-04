# frozen_string_literal: true

module RufletStudio
  module SectionsMisc
    def build_charts(page, status)
      bar_chart = control(
        :barchart,
        width: 320,
        height: 180,
        max_y: 110,
        border: { width: 1, color: "#2a2e36" },
        horizontal_grid_lines: { color: "#2a2e36", width: 1, dash_pattern: [3, 3] },
        tooltip: nil,
        left_axis: control(:chartaxis, label_size: 40, title: text(value: "Fruit supply"), title_size: 40),
        right_axis: control(:chartaxis, show_labels: false),
        bottom_axis: control(
          :chartaxis,
          label_size: 40,
          labels: [
            control(:chartaxislabel, value: 0, label: container(content: text(value: "Apple"), padding: 10)),
            control(:chartaxislabel, value: 1, label: container(content: text(value: "Blueberry"), padding: 10)),
            control(:chartaxislabel, value: 2, label: container(content: text(value: "Cherry"), padding: 10)),
            control(:chartaxislabel, value: 3, label: container(content: text(value: "Orange"), padding: 10))
          ]
        ),
        groups: [
          control(:barchartgroup, x: 0, rods: [control(:barchartrod, from_y: 0, to_y: 40, width: 40, color: "#69db7c", border_radius: 0)]),
          control(:barchartgroup, x: 1, rods: [control(:barchartrod, from_y: 0, to_y: 100, width: 40, color: "#4dabf7", border_radius: 0)]),
          control(:barchartgroup, x: 2, rods: [control(:barchartrod, from_y: 0, to_y: 30, width: 40, color: "#ff6b6b", border_radius: 0)]),
          control(:barchartgroup, x: 3, rods: [control(:barchartrod, from_y: 0, to_y: 60, width: 40, color: "#ffa94d", border_radius: 0)])
        ]
      )

      line_chart = control(
        :linechart,
        data_series: [
          control(:linechartdata, points: [
            control(:linechartdatapoint, x: 1, y: 1),
            control(:linechartdatapoint, x: 3, y: 1.5),
            control(:linechartdatapoint, x: 5, y: 1.4),
            control(:linechartdatapoint, x: 7, y: 3.4)
          ], stroke_width: 4, color: "#51cf66", curved: true, rounded_stroke_cap: true),
          control(:linechartdata, points: [
            control(:linechartdatapoint, x: 1, y: 1),
            control(:linechartdatapoint, x: 3, y: 2.8),
            control(:linechartdatapoint, x: 7, y: 1.2),
            control(:linechartdatapoint, x: 10, y: 2.8)
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

      pie_chart = control(
        :piechart,
        width: 220,
        height: 220,
        sections_space: 0,
        center_space_radius: 0,
        sections: [
          control(:piechartsection, value: 40, title: "40%", color: "#4dabf7", radius: 100),
          control(:piechartsection, value: 30, title: "30%", color: "#ffd43b", radius: 100),
          control(:piechartsection, value: 15, title: "15%", color: "#845ef7", radius: 100),
          control(:piechartsection, value: 15, title: "15%", color: "#51cf66", radius: 100)
        ],
        on_event: ->(e) { page.update(status, value: "Pie chart event: #{e.data}") }
      )

      candlestick_chart = control(
        :candlestickchart,
        width: 320,
        height: 180,
        min_x: -0.5,
        max_x: 6.5,
        min_y: 22,
        max_y: 36,
        spots: [
          control(:candlestickchartspot, x: 0, open: 24.8, high: 28.6, low: 23.9, close: 27.2, selected: true),
          control(:candlestickchartspot, x: 1, open: 27.2, high: 30.1, low: 25.8, close: 28.4)
        ],
        tooltip: nil,
        on_event: ->(e) { page.update(status, value: "Candlestick event: #{e.data}") }
      )

      radar_chart = control(
        :radarchart,
        width: 300,
        height: 180,
        titles: [
          control(:radarcharttitle, text: "macOS"),
          control(:radarcharttitle, text: "Linux"),
          control(:radarcharttitle, text: "Windows")
        ],
        data_sets: [
          control(:radardataset, entries: [
            control(:radardatasetentry, value: 300),
            control(:radardatasetentry, value: 50),
            control(:radardatasetentry, value: 250)
          ])
        ],
        on_event: ->(e) { page.update(status, value: "Radar event: #{e.data}") }
      )

      scatter_chart = control(
        :scatterchart,
        width: 300,
        height: 180,
        min_x: 0,
        max_x: 50,
        min_y: 0,
        max_y: 50,
        left_axis: control(:chartaxis, show_labels: false),
        right_axis: control(:chartaxis, show_labels: false),
        top_axis: control(:chartaxis, show_labels: false),
        bottom_axis: control(:chartaxis, show_labels: false),
        on_event: ->(e) { page.update(status, value: "Scatter event: #{e.data}") },
        spots: [
          control(:scatterchartspot, x: 10, y: 10, radius: 6, color: "#339af0"),
          control(:scatterchartspot, x: 20, y: 25, radius: 10, color: "#ff922b"),
          control(:scatterchartspot, x: 35, y: 40, radius: 8, color: "#51cf66")
        ]
      )

      column(
        spacing: 12,
        tight: true,
        controls: [
          text(value: "BarChart", size: 14, weight: "w600", color: "#e7e9ec"),
          bar_chart,
          text(value: "LineChart", size: 14, weight: "w600", color: "#e7e9ec"),
          line_chart,
          text(value: "PieChart", size: 14, weight: "w600", color: "#e7e9ec"),
          pie_chart,
          text(value: "CandlestickChart", size: 14, weight: "w600", color: "#e7e9ec"),
          candlestick_chart,
          text(value: "RadarChart", size: 14, weight: "w600", color: "#e7e9ec"),
          radar_chart,
          text(value: "ScatterChart", size: 14, weight: "w600", color: "#e7e9ec"),
          scatter_chart
        ]
      )
    end
  end
end
