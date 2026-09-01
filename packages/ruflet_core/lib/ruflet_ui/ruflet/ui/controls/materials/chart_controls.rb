# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # Flet Charts evolves independently from core Flet. Keep its Ruby
        # controls open to the extension's current property surface while
        # retaining typed classes and exact wire names.
        class ChartExtensionControl < Ruflet::Control
          KEYWORDS = [].freeze

          def initialize(type:, id: nil, **props)
            compact = {}
            props.each { |key, value| compact[key] = value unless value.nil? }
            super(type: type, id: id, **compact)
          end
        end

        class ChartAxisControl < ChartExtensionControl
          WIRE = "ChartAxis".freeze
          def initialize(id: nil, **props) = super(type: "chartaxis", id: id, **props)
        end

        class ChartAxisLabelControl < ChartExtensionControl
          WIRE = "ChartAxisLabel".freeze
          def initialize(id: nil, **props) = super(type: "chartaxislabel", id: id, **props)
        end

        class BarChartControl < ChartExtensionControl
          WIRE = "BarChart".freeze
          def initialize(id: nil, **props) = super(type: "barchart", id: id, **props)
        end

        class BarChartGroupControl < ChartExtensionControl
          WIRE = "BarChartGroup".freeze
          def initialize(id: nil, **props) = super(type: "barchartgroup", id: id, **props)
        end

        class BarChartRodControl < ChartExtensionControl
          WIRE = "BarChartRod".freeze
          def initialize(id: nil, **props) = super(type: "barchartrod", id: id, **props)
        end

        class BarChartRodStackItemControl < ChartExtensionControl
          WIRE = "BarChartRodStackItem".freeze
          def initialize(id: nil, **props) = super(type: "barchartrodstackitem", id: id, **props)
        end

        class LineChartControl < ChartExtensionControl
          WIRE = "LineChart".freeze
          def initialize(id: nil, **props) = super(type: "linechart", id: id, **props)
        end

        class LineChartDataControl < ChartExtensionControl
          WIRE = "LineChartData".freeze
          def initialize(id: nil, **props) = super(type: "linechartdata", id: id, **props)
        end

        class LineChartDataPointControl < ChartExtensionControl
          WIRE = "LineChartDataPoint".freeze
          def initialize(id: nil, **props) = super(type: "linechartdatapoint", id: id, **props)
        end

        class PieChartControl < ChartExtensionControl
          WIRE = "PieChart".freeze
          def initialize(id: nil, **props) = super(type: "piechart", id: id, **props)
        end

        class PieChartSectionControl < ChartExtensionControl
          WIRE = "PieChartSection".freeze
          def initialize(id: nil, **props) = super(type: "piechartsection", id: id, **props)
        end

        class CandlestickChartControl < ChartExtensionControl
          WIRE = "CandlestickChart".freeze
          def initialize(id: nil, **props) = super(type: "candlestickchart", id: id, **props)
        end

        class CandlestickChartSpotControl < ChartExtensionControl
          WIRE = "CandlestickChartSpot".freeze
          def initialize(id: nil, **props) = super(type: "candlestickchartspot", id: id, **props)
        end

        class RadarChartControl < ChartExtensionControl
          WIRE = "RadarChart".freeze
          def initialize(id: nil, **props) = super(type: "radarchart", id: id, **props)
        end

        class RadarChartTitleControl < ChartExtensionControl
          WIRE = "RadarChartTitle".freeze
          def initialize(id: nil, **props) = super(type: "radarcharttitle", id: id, **props)
        end

        class RadarDataSetControl < ChartExtensionControl
          WIRE = "RadarDataSet".freeze
          def initialize(id: nil, **props) = super(type: "radardataset", id: id, **props)
        end

        class RadarDataSetEntryControl < ChartExtensionControl
          WIRE = "RadarDataSetEntry".freeze
          def initialize(id: nil, **props) = super(type: "radardatasetentry", id: id, **props)
        end

        class ScatterChartControl < ChartExtensionControl
          WIRE = "ScatterChart".freeze
          def initialize(id: nil, **props) = super(type: "scatterchart", id: id, **props)
        end

        class ScatterChartSpotControl < ChartExtensionControl
          WIRE = "ScatterChartSpot".freeze
          def initialize(id: nil, **props) = super(type: "scatterchartspot", id: id, **props)
        end
      end
    end
  end
end
