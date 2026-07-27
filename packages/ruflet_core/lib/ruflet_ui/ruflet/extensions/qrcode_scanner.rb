# frozen_string_literal: true

module Ruflet
  module Extensions
    class QrCodeScannerControl < Ruflet::Control
      TYPE = "qrcode_scanner".freeze
      WIRE = "qrcode_scanner".freeze
      KEYWORDS = %i[
        align animate_align animate_margin animate_offset animate_opacity
        animate_position animate_rotation animate_scale animate_size aspect_ratio
        auto_start auto_zoom badge bottom camera_facing col data detection_speed
        detection_timeout disabled expand expand_loose fit formats height
        invert_image key left margin offset opacity return_image right rotate rtl
        scale scan_window size_change_interval tap_to_focus tooltip top
        torch_enabled visible width zoom_scale on_animation_end on_detect on_error
        on_size_change
      ].freeze

      def initialize(id: nil, **props)
        super(type: TYPE, id: id, **props)
      end

      def start(timeout: 10, on_result: nil)
        invoke_scanner("start", timeout: timeout, on_result: on_result)
      end

      def stop(timeout: 10, on_result: nil)
        invoke_scanner("stop", timeout: timeout, on_result: on_result)
      end

      def switch_camera(timeout: 10, on_result: nil)
        invoke_scanner("switch_camera", timeout: timeout, on_result: on_result)
      end

      def toggle_torch(timeout: 10, on_result: nil)
        invoke_scanner("toggle_torch", timeout: timeout, on_result: on_result)
      end

      def set_zoom_scale(value, timeout: 10, on_result: nil)
        invoke_scanner("set_zoom_scale", args: { "value" => value }, timeout: timeout, on_result: on_result)
      end

      def reset_zoom_scale(timeout: 10, on_result: nil)
        invoke_scanner("reset_zoom_scale", timeout: timeout, on_result: on_result)
      end

      private

      def preprocess_props(props)
        mapped = props.dup
        mapped[:formats] = Array(mapped[:formats]).map(&:to_s) if mapped.key?(:formats)
        mapped["formats"] = Array(mapped["formats"]).map(&:to_s) if mapped.key?("formats")
        mapped
      end

      def invoke_scanner(name, args: nil, timeout: 10, on_result: nil)
        runtime_page&.invoke(self, name, args: args, timeout: timeout, on_result: on_result)
      end
    end

    register_control(
      :qrcode_scanner,
      control_class: QrCodeScannerControl,
      flutter: {
        package: "ruflet_qrcode_scanner",
        import: "package:ruflet_qrcode_scanner/ruflet_qrcode_scanner.dart",
        alias: "ruflet_qrcode_scanner",
        constructor: "Extension"
      }
    )
  end
end
