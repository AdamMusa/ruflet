# frozen_string_literal: true

module RufletStudio
  module SectionsMisc
    def build_charts(page, status)
      bar_chart = page.control(
        :barchart,
        width: 360,
        height: 220,
        max_y: 110,
        border: { width: 1, color: "#2a2e36" },
        horizontal_grid_lines: { color: "#2a2e36", width: 1, dash_pattern: [3, 3] },
        tooltip: nil,
        left_axis: page.control(:chartaxis, label_size: 40, title: page.text(value: "Fruit supply"), title_size: 40),
        right_axis: page.control(:chartaxis, show_labels: false),
        bottom_axis: page.control(
          :chartaxis,
          label_size: 40,
          labels: [
            page.control(:chartaxislabel, value: 0, label: page.container(content: page.text(value: "Apple"), padding: 10)),
            page.control(:chartaxislabel, value: 1, label: page.container(content: page.text(value: "Blueberry"), padding: 10)),
            page.control(:chartaxislabel, value: 2, label: page.container(content: page.text(value: "Cherry"), padding: 10)),
            page.control(:chartaxislabel, value: 3, label: page.container(content: page.text(value: "Orange"), padding: 10))
          ]
        ),
        groups: [
          page.control(:barchartgroup, x: 0, rods: [page.control(:barchartrod, from_y: 0, to_y: 40, width: 40, color: "#69db7c", border_radius: 0)]),
          page.control(:barchartgroup, x: 1, rods: [page.control(:barchartrod, from_y: 0, to_y: 100, width: 40, color: "#4dabf7", border_radius: 0)]),
          page.control(:barchartgroup, x: 2, rods: [page.control(:barchartrod, from_y: 0, to_y: 30, width: 40, color: "#ff6b6b", border_radius: 0)]),
          page.control(:barchartgroup, x: 3, rods: [page.control(:barchartrod, from_y: 0, to_y: 60, width: 40, color: "#ffa94d", border_radius: 0)])
        ]
      )

      line_chart = page.control(
        :linechart,
        data_series: [
          page.control(:linechartdata, points: [
            page.control(:linechartdatapoint, x: 1, y: 1),
            page.control(:linechartdatapoint, x: 3, y: 1.5),
            page.control(:linechartdatapoint, x: 5, y: 1.4),
            page.control(:linechartdatapoint, x: 7, y: 3.4)
          ], stroke_width: 4, color: "#51cf66", curved: true, rounded_stroke_cap: true),
          page.control(:linechartdata, points: [
            page.control(:linechartdatapoint, x: 1, y: 1),
            page.control(:linechartdatapoint, x: 3, y: 2.8),
            page.control(:linechartdatapoint, x: 7, y: 1.2),
            page.control(:linechartdatapoint, x: 10, y: 2.8)
          ], stroke_width: 4, color: "#f06595", curved: true, rounded_stroke_cap: true)
        ],
        min_y: 0,
        max_y: 4,
        min_x: 0,
        max_x: 14,
        interactive: true,
        width: 360,
        height: 220,
        tooltip: nil,
        on_event: ->(e) { page.update(status, value: "Line chart event: #{e.data}") }
      )

      pie_chart = page.control(
        :piechart,
        width: 260,
        height: 260,
        sections_space: 0,
        center_space_radius: 0,
        sections: [
          page.control(:piechartsection, value: 40, title: "40%", color: "#4dabf7", radius: 100),
          page.control(:piechartsection, value: 30, title: "30%", color: "#ffd43b", radius: 100),
          page.control(:piechartsection, value: 15, title: "15%", color: "#845ef7", radius: 100),
          page.control(:piechartsection, value: 15, title: "15%", color: "#51cf66", radius: 100)
        ],
        on_event: ->(e) { page.update(status, value: "Pie chart event: #{e.data}") }
      )

      candlestick_chart = page.control(
        :candlestickchart,
        width: 360,
        height: 220,
        min_x: -0.5,
        max_x: 6.5,
        min_y: 22,
        max_y: 36,
        spots: [
          page.control(:candlestickchartspot, x: 0, open: 24.8, high: 28.6, low: 23.9, close: 27.2, selected: true),
          page.control(:candlestickchartspot, x: 1, open: 27.2, high: 30.1, low: 25.8, close: 28.4)
        ],
        tooltip: nil,
        on_event: ->(e) { page.update(status, value: "Candlestick event: #{e.data}") }
      )

      radar_chart = page.control(
        :radarchart,
        width: 320,
        height: 220,
        titles: [
          page.control(:radarcharttitle, text: "macOS"),
          page.control(:radarcharttitle, text: "Linux"),
          page.control(:radarcharttitle, text: "Windows")
        ],
        data_sets: [
          page.control(:radardataset, entries: [
            page.control(:radardatasetentry, value: 300),
            page.control(:radardatasetentry, value: 50),
            page.control(:radardatasetentry, value: 250)
          ])
        ],
        on_event: ->(e) { page.update(status, value: "Radar event: #{e.data}") }
      )

      scatter_chart = page.control(
        :scatterchart,
        width: 320,
        height: 220,
        min_x: 0,
        max_x: 50,
        min_y: 0,
        max_y: 50,
        left_axis: page.control(:chartaxis, show_labels: false),
        right_axis: page.control(:chartaxis, show_labels: false),
        top_axis: page.control(:chartaxis, show_labels: false),
        bottom_axis: page.control(:chartaxis, show_labels: false),
        on_event: ->(e) { page.update(status, value: "Scatter event: #{e.data}") },
        spots: [
          page.control(:scatterchartspot, x: 10, y: 10, radius: 6, color: "#339af0"),
          page.control(:scatterchartspot, x: 20, y: 25, radius: 10, color: "#ff922b"),
          page.control(:scatterchartspot, x: 35, y: 40, radius: 8, color: "#51cf66")
        ]
      )

      page.column(
        spacing: 12,
        controls: [
          page.text(value: "BarChart", size: 14, weight: "w600", color: "#e7e9ec"),
          bar_chart,
          page.text(value: "LineChart", size: 14, weight: "w600", color: "#e7e9ec"),
          line_chart,
          page.text(value: "PieChart", size: 14, weight: "w600", color: "#e7e9ec"),
          pie_chart,
          page.text(value: "CandlestickChart", size: 14, weight: "w600", color: "#e7e9ec"),
          candlestick_chart,
          page.text(value: "RadarChart", size: 14, weight: "w600", color: "#e7e9ec"),
          radar_chart,
          page.text(value: "ScatterChart", size: 14, weight: "w600", color: "#e7e9ec"),
          scatter_chart
        ]
      )
    end

    def build_drawing(page, status)
      canvas = page.control(
        :canvas,
        width: 260,
        height: 260,
        shapes: [
          page.control(:line, x1: 10, y1: 10, x2: 250, y2: 250, paint: { stroke_width: 3, color: "#ff6b6b" })
        ],
        content: page.gesture_detector(
          on_pan_start: ->(e) { page.update(status, value: "Canvas pan start: #{fmt_pos(e)}") },
          on_pan_update: ->(e) { page.update(status, value: "Canvas pan update: #{fmt_pos(e)}") }
        )
      )

      page.column(spacing: 8, controls: [status, canvas])
    end

    def build_minesweeper(page, status)
      minesweeper_board = page.gesture_detector(
        on_tap_down: ->(e) { page.update(status, value: "Minesweeper tap: #{fmt_pos(e)}") },
        on_long_press_start: ->(e) { page.update(status, value: "Minesweeper long press: #{fmt_pos(e)}") },
        content: page.stack(
          width: 9 * 26,
          height: 9 * 26,
          controls: build_minesweeper_grid(page)
        )
      )

      page.column(spacing: 8, controls: [status, minesweeper_board])
    end

    def build_minesweeper_grid(page)
      size = 26
      controls = []
      9.times do |r|
        9.times do |c|
          controls << page.container(
            width: size,
            height: size,
            left: c * size,
            top: r * size,
            bgcolor: r.even? == c.even? ? "#2a2e36" : "#23272f",
            border: { width: 1, color: "#1c1f26" }
          )
        end
      end
      controls
    end
  end
end
