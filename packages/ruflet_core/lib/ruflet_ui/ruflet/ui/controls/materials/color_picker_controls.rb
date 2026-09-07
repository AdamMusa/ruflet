# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ColorPickerExtensionControl < Ruflet::Control
          def initialize(type:, id: nil, **props)
            compact = {}
            props.each { |key, value| compact[key] = value unless value.nil? }
            super(type: type, id: id, **compact)
          end
        end

        {
          BlockPickerControl: ["block_picker", "BlockPicker"],
          ColorPickerControl: ["color_picker", "ColorPicker"],
          HueRingPickerControl: ["hue_ring_picker", "HueRingPicker"],
          MaterialPickerControl: ["material_picker", "MaterialPicker"],
          MultipleChoiceBlockPickerControl: ["multiple_choice_block_picker", "MultipleChoiceBlockPicker"],
          SlidePickerControl: ["slide_picker", "SlidePicker"]
        }.each do |class_name, (type, wire)|
          klass = Class.new(ColorPickerExtensionControl) do
            const_set(:WIRE, wire.freeze)
            define_method(:initialize) do |id: nil, **props|
              super(type: type, id: id, **props)
            end
          end
          const_set(class_name, klass)
        end
      end
    end
  end
end
