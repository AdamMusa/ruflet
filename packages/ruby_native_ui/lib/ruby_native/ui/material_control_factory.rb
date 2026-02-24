# frozen_string_literal: true

require_relative "controls/material/text_control"
require_relative "controls/material/view_control"
require_relative "controls/material/container_control"
require_relative "controls/material/column_control"
require_relative "controls/material/row_control"
require_relative "controls/material/stack_control"
require_relative "controls/material/gesture_detector_control"
require_relative "controls/material/draggable_control"
require_relative "controls/material/drag_target_control"
require_relative "controls/material/text_field_control"
require_relative "controls/material/button_control"
require_relative "controls/material/elevated_button_control"
require_relative "controls/material/text_button_control"
require_relative "controls/material/filled_button_control"
require_relative "controls/material/icon_button_control"
require_relative "controls/material/icon_control"
require_relative "controls/material/image_control"
require_relative "controls/material/app_bar_control"
require_relative "controls/material/floating_action_button_control"
require_relative "controls/material/checkbox_control"
require_relative "controls/material/radio_control"
require_relative "controls/material/radio_group_control"
require_relative "controls/material/alert_dialog_control"
require_relative "controls/material/snack_bar_control"
require_relative "controls/material/bottom_sheet_control"
require_relative "controls/material/markdown_control"
require_relative "controls/material/tabs_control"
require_relative "controls/material/tab_control"
require_relative "controls/material/tab_bar_control"
require_relative "controls/material/tab_bar_view_control"
require_relative "controls/material/navigation_bar_control"
require_relative "controls/material/navigation_bar_destination_control"

module RubyNative
  module UI
    module MaterialControlFactory
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
        "floating_action_button" => Controls::FloatingActionButtonControl,
        "checkbox" => Controls::CheckboxControl,
        "radio" => Controls::RadioControl,
        "radiogroup" => Controls::RadioGroupControl,
        "radio_group" => Controls::RadioGroupControl,
        "alertdialog" => Controls::AlertDialogControl,
        "alert_dialog" => Controls::AlertDialogControl,
        "snackbar" => Controls::SnackBarControl,
        "snack_bar" => Controls::SnackBarControl,
        "bottomsheet" => Controls::BottomSheetControl,
        "bottom_sheet" => Controls::BottomSheetControl,
        "markdown" => Controls::MarkdownControl,
        "tabs" => Controls::TabsControl,
        "tab" => Controls::TabControl,
        "tabbar" => Controls::TabBarControl,
        "tab_bar" => Controls::TabBarControl,
        "tabbarview" => Controls::TabBarViewControl,
        "tab_bar_view" => Controls::TabBarViewControl,
        "navigationbar" => Controls::NavigationBarControl,
        "navigation_bar" => Controls::NavigationBarControl,
        "navigationbardestination" => Controls::NavigationBarDestinationControl,
        "navigation_bar_destination" => Controls::NavigationBarDestinationControl
      }.freeze
    end
  end
end
