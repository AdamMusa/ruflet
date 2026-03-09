# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class ScreenBrightnessControl < Ruflet::Control
          TYPE = "screenbrightness".freeze
          WIRE = "ScreenBrightness".freeze

          def initialize(id: nil, data: nil, key: nil, on_application_screen_brightness_change: nil, on_system_screen_brightness_change: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            props[:on_application_screen_brightness_change] = on_application_screen_brightness_change unless on_application_screen_brightness_change.nil?
            props[:on_system_screen_brightness_change] = on_system_screen_brightness_change unless on_system_screen_brightness_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
