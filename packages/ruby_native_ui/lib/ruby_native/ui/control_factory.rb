# frozen_string_literal: true

require_relative "controls/text_control"
require_relative "controls/view_control"
require_relative "controls/container_control"
require_relative "controls/column_control"
require_relative "controls/row_control"
require_relative "controls/stack_control"
require_relative "controls/gesture_detector_control"
require_relative "controls/draggable_control"
require_relative "controls/drag_target_control"
require_relative "controls/text_field_control"
require_relative "controls/button_control"
require_relative "controls/elevated_button_control"
require_relative "controls/text_button_control"
require_relative "controls/filled_button_control"
require_relative "controls/icon_button_control"
require_relative "controls/icon_control"
require_relative "controls/image_control"
require_relative "controls/app_bar_control"
require_relative "controls/floating_action_button_control"
require_relative "controls/checkbox_control"
require_relative "controls/radio_control"
require_relative "controls/radio_group_control"
require_relative "controls/alert_dialog_control"
require_relative "controls/markdown_control"

module RubyNative
  module UI
    module ControlFactory
      module_function

      CLASS_MAP = {
        "text" => Controls::TextControl,
        "view" => Controls::ViewControl,
        "column" => Controls::ColumnControl,
        "row" => Controls::RowControl,
        "stack" => Controls::StackControl,
        "container" => Controls::ContainerControl,
        "gesturedetector" => Controls::GestureDetectorControl,
        "gesture_detector" => Controls::GestureDetectorControl,
        "draggable" => Controls::DraggableControl,
        "dragtarget" => Controls::DragTargetControl,
        "drag_target" => Controls::DragTargetControl,
        "textfield" => Controls::TextFieldControl,
        "text_field" => Controls::TextFieldControl,
        "button" => Controls::ButtonControl,
        "elevatedbutton" => Controls::ElevatedButtonControl,
        "elevated_button" => Controls::ElevatedButtonControl,
        "textbutton" => Controls::TextButtonControl,
        "text_button" => Controls::TextButtonControl,
        "filledbutton" => Controls::FilledButtonControl,
        "filled_button" => Controls::FilledButtonControl,
        "iconbutton" => Controls::IconButtonControl,
        "icon_button" => Controls::IconButtonControl,
        "icon" => Controls::IconControl,
        "image" => Controls::ImageControl,
        "appbar" => Controls::AppBarControl,
        "app_bar" => Controls::AppBarControl,
        "floatingactionbutton" => Controls::FloatingActionButtonControl,
        "checkbox" => Controls::CheckboxControl,
        "radio" => Controls::RadioControl,
        "radiogroup" => Controls::RadioGroupControl,
        "radio_group" => Controls::RadioGroupControl,
        "alertdialog" => Controls::AlertDialogControl,
        "alert_dialog" => Controls::AlertDialogControl,
        "markdown" => Controls::MarkdownControl
      }.freeze

      def build(type, id: nil, **props)
        normalized_type = type.to_s.downcase
        klass = CLASS_MAP[normalized_type]
        raise ArgumentError, "Unsupported control type: #{normalized_type}" unless klass

        klass.new(id: id, **props)
      end
    end
  end
end
