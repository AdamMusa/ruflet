# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ChartAxisControl < Ruflet::Control
          TYPE = "chartaxis".freeze
          WIRE = "axis".freeze

          def initialize(id: nil, title: nil, labels: nil, label_size: nil, title_size: nil, show_labels: nil)
            props = {}
            props[:title] = title unless title.nil?
            props[:labels] = labels unless labels.nil?
            props[:label_size] = label_size unless label_size.nil?
            props[:title_size] = title_size unless title_size.nil?
            props[:show_labels] = show_labels unless show_labels.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class ChartAxisLabelControl < Ruflet::Control
          TYPE = "chartaxislabel".freeze
          WIRE = "l".freeze

          def initialize(id: nil, value: nil, label: nil)
            props = {}
            props[:value] = value unless value.nil?
            props[:label] = label unless label.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class BarChartControl < Ruflet::Control
          TYPE = "barchart".freeze
          WIRE = "BarChart".freeze

          def initialize(id: nil, width: nil, height: nil, min_y: nil, max_y: nil, min_x: nil, max_x: nil, groups: nil, left_axis: nil, right_axis: nil, top_axis: nil, bottom_axis: nil, horizontal_grid_lines: nil, vertical_grid_lines: nil, border: nil, tooltip: nil, on_event: nil)
            props = {}
            props[:width] = width unless width.nil?
            props[:height] = height unless height.nil?
            props[:min_y] = min_y unless min_y.nil?
            props[:max_y] = max_y unless max_y.nil?
            props[:min_x] = min_x unless min_x.nil?
            props[:max_x] = max_x unless max_x.nil?
            props[:groups] = groups unless groups.nil?
            props[:left_axis] = left_axis unless left_axis.nil?
            props[:right_axis] = right_axis unless right_axis.nil?
            props[:top_axis] = top_axis unless top_axis.nil?
            props[:bottom_axis] = bottom_axis unless bottom_axis.nil?
            props[:horizontal_grid_lines] = horizontal_grid_lines unless horizontal_grid_lines.nil?
            props[:vertical_grid_lines] = vertical_grid_lines unless vertical_grid_lines.nil?
            props[:border] = border unless border.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:on_event] = on_event unless on_event.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class BarChartGroupControl < Ruflet::Control
          TYPE = "barchartgroup".freeze
          WIRE = "group".freeze

          def initialize(id: nil, x: nil, rods: nil, bars_space: nil, showing_tooltip_indicators: nil)
            props = {}
            props[:x] = x unless x.nil?
            props[:rods] = rods unless rods.nil?
            props[:bars_space] = bars_space unless bars_space.nil?
            props[:showing_tooltip_indicators] = showing_tooltip_indicators unless showing_tooltip_indicators.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class BarChartRodControl < Ruflet::Control
          TYPE = "barchartrod".freeze
          WIRE = "rod".freeze

          def initialize(id: nil, from_y: nil, to_y: nil, width: nil, color: nil, gradient: nil, border_radius: nil, rod_stack_items: nil)
            props = {}
            props[:from_y] = from_y unless from_y.nil?
            props[:to_y] = to_y unless to_y.nil?
            props[:width] = width unless width.nil?
            props[:color] = color unless color.nil?
            props[:gradient] = gradient unless gradient.nil?
            props[:border_radius] = border_radius unless border_radius.nil?
            props[:rod_stack_items] = rod_stack_items unless rod_stack_items.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class BarChartRodStackItemControl < Ruflet::Control
          TYPE = "barchartrodstackitem".freeze
          WIRE = "stack_item".freeze

          def initialize(id: nil, from_y: nil, to_y: nil, color: nil, border_side: nil)
            props = {}
            props[:from_y] = from_y unless from_y.nil?
            props[:to_y] = to_y unless to_y.nil?
            props[:color] = color unless color.nil?
            props[:border_side] = border_side unless border_side.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class LineChartControl < Ruflet::Control
          TYPE = "linechart".freeze
          WIRE = "LineChart".freeze

          def initialize(id: nil, width: nil, height: nil, min_y: nil, max_y: nil, min_x: nil, max_x: nil, data_series: nil, left_axis: nil, right_axis: nil, top_axis: nil, bottom_axis: nil, interactive: nil, tooltip: nil, on_event: nil)
            props = {}
            props[:width] = width unless width.nil?
            props[:height] = height unless height.nil?
            props[:min_y] = min_y unless min_y.nil?
            props[:max_y] = max_y unless max_y.nil?
            props[:min_x] = min_x unless min_x.nil?
            props[:max_x] = max_x unless max_x.nil?
            props[:data_series] = data_series unless data_series.nil?
            props[:left_axis] = left_axis unless left_axis.nil?
            props[:right_axis] = right_axis unless right_axis.nil?
            props[:top_axis] = top_axis unless top_axis.nil?
            props[:bottom_axis] = bottom_axis unless bottom_axis.nil?
            props[:interactive] = interactive unless interactive.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:on_event] = on_event unless on_event.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class LineChartDataControl < Ruflet::Control
          TYPE = "linechartdata".freeze
          WIRE = "data".freeze

          def initialize(id: nil, points: nil, color: nil, gradient: nil, stroke_width: nil, curved: nil, rounded_stroke_cap: nil)
            props = {}
            props[:points] = points unless points.nil?
            props[:color] = color unless color.nil?
            props[:gradient] = gradient unless gradient.nil?
            props[:stroke_width] = stroke_width unless stroke_width.nil?
            props[:curved] = curved unless curved.nil?
            props[:rounded_stroke_cap] = rounded_stroke_cap unless rounded_stroke_cap.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class LineChartDataPointControl < Ruflet::Control
          TYPE = "linechartdatapoint".freeze
          WIRE = "p".freeze

          def initialize(id: nil, x: nil, y: nil)
            props = {}
            props[:x] = x unless x.nil?
            props[:y] = y unless y.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class PieChartControl < Ruflet::Control
          TYPE = "piechart".freeze
          WIRE = "PieChart".freeze

          def initialize(id: nil, width: nil, height: nil, sections: nil, sections_space: nil, center_space_radius: nil, tooltip: nil, on_event: nil)
            props = {}
            props[:width] = width unless width.nil?
            props[:height] = height unless height.nil?
            props[:sections] = sections unless sections.nil?
            props[:sections_space] = sections_space unless sections_space.nil?
            props[:center_space_radius] = center_space_radius unless center_space_radius.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:on_event] = on_event unless on_event.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class PieChartSectionControl < Ruflet::Control
          TYPE = "piechartsection".freeze
          WIRE = "section".freeze

          def initialize(id: nil, value: nil, title: nil, color: nil, radius: nil, title_style: nil, badge_widget: nil, badge_position_percentage_offset: nil)
            props = {}
            props[:value] = value unless value.nil?
            props[:title] = title unless title.nil?
            props[:color] = color unless color.nil?
            props[:radius] = radius unless radius.nil?
            props[:title_style] = title_style unless title_style.nil?
            props[:badge_widget] = badge_widget unless badge_widget.nil?
            props[:badge_position_percentage_offset] = badge_position_percentage_offset unless badge_position_percentage_offset.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class CandlestickChartControl < Ruflet::Control
          TYPE = "candlestickchart".freeze
          WIRE = "CandlestickChart".freeze

          def initialize(id: nil, width: nil, height: nil, min_x: nil, max_x: nil, min_y: nil, max_y: nil, spots: nil, left_axis: nil, right_axis: nil, top_axis: nil, bottom_axis: nil, tooltip: nil, on_event: nil)
            props = {}
            props[:width] = width unless width.nil?
            props[:height] = height unless height.nil?
            props[:min_x] = min_x unless min_x.nil?
            props[:max_x] = max_x unless max_x.nil?
            props[:min_y] = min_y unless min_y.nil?
            props[:max_y] = max_y unless max_y.nil?
            props[:spots] = spots unless spots.nil?
            props[:left_axis] = left_axis unless left_axis.nil?
            props[:right_axis] = right_axis unless right_axis.nil?
            props[:top_axis] = top_axis unless top_axis.nil?
            props[:bottom_axis] = bottom_axis unless bottom_axis.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:on_event] = on_event unless on_event.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class CandlestickChartSpotControl < Ruflet::Control
          TYPE = "candlestickchartspot".freeze
          WIRE = "CandlestickChartSpot".freeze

          def initialize(id: nil, x: nil, open: nil, high: nil, low: nil, close: nil, selected: nil)
            props = {}
            props[:x] = x unless x.nil?
            props[:open] = open unless open.nil?
            props[:high] = high unless high.nil?
            props[:low] = low unless low.nil?
            props[:close] = close unless close.nil?
            props[:selected] = selected unless selected.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class RadarChartControl < Ruflet::Control
          TYPE = "radarchart".freeze
          WIRE = "RadarChart".freeze

          def initialize(id: nil, width: nil, height: nil, titles: nil, data_sets: nil, on_event: nil)
            props = {}
            props[:width] = width unless width.nil?
            props[:height] = height unless height.nil?
            props[:titles] = titles unless titles.nil?
            props[:data_sets] = data_sets unless data_sets.nil?
            props[:on_event] = on_event unless on_event.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class RadarChartTitleControl < Ruflet::Control
          TYPE = "radarcharttitle".freeze
          WIRE = "RadarChartTitle".freeze

          def initialize(id: nil, text: nil, angle: nil, position_percentage_offset: nil)
            props = {}
            props[:text] = text unless text.nil?
            props[:angle] = angle unless angle.nil?
            props[:position_percentage_offset] = position_percentage_offset unless position_percentage_offset.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class RadarDataSetControl < Ruflet::Control
          TYPE = "radardataset".freeze
          WIRE = "RadarDataSet".freeze

          def initialize(id: nil, entries: nil, border_color: nil, fill_color: nil, border_width: nil)
            props = {}
            props[:entries] = entries unless entries.nil?
            props[:border_color] = border_color unless border_color.nil?
            props[:fill_color] = fill_color unless fill_color.nil?
            props[:border_width] = border_width unless border_width.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class RadarDataSetEntryControl < Ruflet::Control
          TYPE = "radardatasetentry".freeze
          WIRE = "RadarDataSetEntry".freeze

          def initialize(id: nil, value: nil)
            props = {}
            props[:value] = value unless value.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class ScatterChartControl < Ruflet::Control
          TYPE = "scatterchart".freeze
          WIRE = "ScatterChart".freeze

          def initialize(id: nil, width: nil, height: nil, min_x: nil, max_x: nil, min_y: nil, max_y: nil, spots: nil, left_axis: nil, right_axis: nil, top_axis: nil, bottom_axis: nil, on_event: nil)
            props = {}
            props[:width] = width unless width.nil?
            props[:height] = height unless height.nil?
            props[:min_x] = min_x unless min_x.nil?
            props[:max_x] = max_x unless max_x.nil?
            props[:min_y] = min_y unless min_y.nil?
            props[:max_y] = max_y unless max_y.nil?
            props[:spots] = spots unless spots.nil?
            props[:left_axis] = left_axis unless left_axis.nil?
            props[:right_axis] = right_axis unless right_axis.nil?
            props[:top_axis] = top_axis unless top_axis.nil?
            props[:bottom_axis] = bottom_axis unless bottom_axis.nil?
            props[:on_event] = on_event unless on_event.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class ScatterChartSpotControl < Ruflet::Control
          TYPE = "scatterchartspot".freeze
          WIRE = "ScatterChartSpot".freeze

          def initialize(id: nil, x: nil, y: nil, radius: nil, color: nil)
            props = {}
            props[:x] = x unless x.nil?
            props[:y] = y unless y.nil?
            props[:radius] = radius unless radius.nil?
            props[:color] = color unless color.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
