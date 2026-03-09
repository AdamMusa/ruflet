# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class FilePickerControl < Ruflet::Control
          TYPE = "filepicker".freeze
          WIRE = "FilePicker".freeze

          def initialize(id: nil, data: nil, key: nil, on_upload: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            props[:on_upload] = on_upload unless on_upload.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
