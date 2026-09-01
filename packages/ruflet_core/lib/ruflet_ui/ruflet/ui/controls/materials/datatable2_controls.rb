# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DataTable2ExtensionControl < Ruflet::Control
          def initialize(type:, id: nil, **props)
            compact = {}
            props.each { |key, value| compact[key] = value unless value.nil? }
            super(type: type, id: id, **compact)
          end
        end

        class DataColumn2Control < DataTable2ExtensionControl
          WIRE = "DataColumn2".freeze

          def initialize(id: nil, **props)
            super(type: "data_column2", id: id, **props)
          end
        end

        class DataRow2Control < DataTable2ExtensionControl
          WIRE = "DataRow2".freeze

          def initialize(id: nil, **props)
            super(type: "data_row2", id: id, **props)
          end
        end

        class DataTable2Control < DataTable2ExtensionControl
          WIRE = "DataTable2".freeze

          def initialize(id: nil, **props)
            super(type: "data_table2", id: id, **props)
          end
        end
      end
    end
  end
end
