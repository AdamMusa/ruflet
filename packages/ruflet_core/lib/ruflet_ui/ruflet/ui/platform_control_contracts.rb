# frozen_string_literal: true

require_relative "controls/ruflet_controls"

module Ruflet
  module UI
    # One Ruby protocol contract for controls whose visual implementation is
    # selected by the Flet client. These schemas deliberately accept the union
    # of the Material and Cupertino properties: Ruby describes intent and the
    # platform renderer decides how that intent looks.
    module PlatformControlContracts
      module Components
        class PlatformControl < Ruflet::Control
          def initialize(id: nil, **props)
            props = platform_defaults.merge(props)
            validate_platform_props!(props)
            compact = {}
            props.each do |key, value|
              raise ArgumentError, "unknown keyword: :#{key}" unless self.class::KEYWORDS.include?(key)

              value = normalize_platform_prop(key, value)
              compact[key] = value unless value.nil?
            end
            super(type: self.class::TYPE, id: id, **compact)
          end

          private

          def platform_defaults = {}
          def validate_platform_props!(_props); end
          def normalize_platform_prop(_key, value) = value

          def require_control_prop!(props, name)
            value = props[name]
            raise ArgumentError, "#{self.class::TYPE} requires #{name}" if value.nil?
          end
        end

        class ButtonControl < PlatformControl
          TYPE = "button".freeze
          WIRE = "Button".freeze
          KEYWORDS = (
            Controls::RufletComponents::ButtonControl::KEYWORDS +
            Controls::RufletComponents::CupertinoButtonControl::KEYWORDS +
            %i[default destructive]
          ).uniq.freeze

        end

        class FilledButtonControl < PlatformControl
          TYPE = "filledbutton".freeze
          WIRE = "FilledButton".freeze
          KEYWORDS = (
            Controls::RufletComponents::FilledButtonControl::KEYWORDS +
            Controls::RufletComponents::CupertinoFilledButtonControl::KEYWORDS
          ).uniq.freeze

          private

          def platform_defaults = { autofocus: false, clip_behavior: "none" }
        end

        class FilledTonalButtonControl < PlatformControl
          TYPE = "filledtonalbutton".freeze
          WIRE = "FilledTonalButton".freeze
          KEYWORDS = (
            Controls::RufletComponents::FilledTonalButtonControl::KEYWORDS +
            Controls::RufletComponents::CupertinoTintedButtonControl::KEYWORDS
          ).uniq.freeze

          private

          def platform_defaults = { autofocus: false, clip_behavior: "none" }
        end

        class OutlinedButtonControl < PlatformControl
          TYPE = "outlinedbutton".freeze
          WIRE = "OutlinedButton".freeze
          KEYWORDS = (
            Controls::RufletComponents::OutlinedButtonControl::KEYWORDS +
            Controls::RufletComponents::CupertinoButtonControl::KEYWORDS
          ).uniq.freeze

          private

          def platform_defaults = { autofocus: false, clip_behavior: "none" }
        end

        class TextButtonControl < PlatformControl
          TYPE = "textbutton".freeze
          WIRE = "TextButton".freeze
          KEYWORDS = (
            Controls::RufletComponents::TextButtonControl::KEYWORDS +
            Controls::RufletComponents::CupertinoButtonControl::KEYWORDS
          ).uniq.freeze

          private

          def platform_defaults = { autofocus: false, clip_behavior: "none" }
        end

        class TextFieldControl < PlatformControl
          TYPE = "textfield".freeze
          WIRE = "TextField".freeze
          KEYWORDS = (
            Controls::RufletComponents::TextFieldControl::KEYWORDS +
            Controls::RufletComponents::CupertinoTextFieldControl::KEYWORDS
          ).uniq.freeze
        end

        class CheckboxControl < PlatformControl
          TYPE = "checkbox".freeze
          WIRE = "Checkbox".freeze
          KEYWORDS = (
            Controls::RufletComponents::CheckboxControl::KEYWORDS +
            Controls::RufletComponents::CupertinoCheckboxControl::KEYWORDS
          ).uniq.freeze
        end

        class RadioControl < PlatformControl
          TYPE = "radio".freeze
          WIRE = "Radio".freeze
          KEYWORDS = (
            Controls::RufletComponents::RadioControl::KEYWORDS +
            Controls::RufletComponents::CupertinoRadioControl::KEYWORDS
          ).uniq.freeze
        end

        class SliderControl < PlatformControl
          TYPE = "slider".freeze
          WIRE = "Slider".freeze
          KEYWORDS = (
            Controls::RufletComponents::SliderControl::KEYWORDS +
            Controls::RufletComponents::CupertinoSliderControl::KEYWORDS
          ).uniq.freeze
        end

        class SwitchControl < PlatformControl
          TYPE = "switch".freeze
          WIRE = "Switch".freeze
          KEYWORDS = (
            Controls::RufletComponents::SwitchControl::KEYWORDS +
            Controls::RufletComponents::CupertinoSwitchControl::KEYWORDS
          ).uniq.freeze
        end

        class AlertDialogControl < PlatformControl
          TYPE = "alertdialog".freeze
          WIRE = "AlertDialog".freeze
          KEYWORDS = (
            Controls::RufletComponents::AlertDialogControl::KEYWORDS +
            %i[inset_animation]
          ).uniq.freeze
        end

        class BottomSheetControl < PlatformControl
          TYPE = "bottomsheet".freeze
          WIRE = "BottomSheet".freeze
          KEYWORDS = %i[
            adaptive animation_style badge barrier_color bgcolor clip_behavior col content data
            disabled dismissible draggable elevation expand expand_loose fullscreen height key
            maintain_bottom_view_insets_padding modal opacity open padding rtl scrollable shape
            show_drag_handle size_constraints tooltip use_safe_area visible on_dismiss
          ].freeze

          private

          def validate_platform_props!(props) = require_control_prop!(props, :content)
        end

        class AppBarControl < PlatformControl
          TYPE = "appbar".freeze
          WIRE = "AppBar".freeze
          KEYWORDS = (
            Controls::RufletComponents::AppBarControl::KEYWORDS + %i[
              automatic_background_visibility automatically_imply_title border brightness
              enable_background_filter_blur large padding previous_page_title trailing
              transition_between_routes
            ]
          ).uniq.freeze
        end

        class ListTileControl < PlatformControl
          TYPE = "listtile".freeze
          WIRE = "ListTile".freeze
          KEYWORDS = (
            Controls::RufletComponents::ListTileControl::KEYWORDS +
            Controls::RufletComponents::CupertinoListTileControl::KEYWORDS
          ).uniq.freeze

          private

          def validate_platform_props!(props) = require_control_prop!(props, :title)
        end

        class NavigationBarControl < PlatformControl
          TYPE = "navigationbar".freeze
          WIRE = "NavigationBar".freeze
          KEYWORDS = (
            Controls::RufletComponents::NavigationBarControl::KEYWORDS +
            Controls::RufletComponents::CupertinoNavigationBarControl::KEYWORDS
          ).uniq.freeze
        end

        class ProgressRingControl < PlatformControl
          TYPE = "progressring".freeze
          WIRE = "ProgressRing".freeze
          KEYWORDS = (
            Controls::RufletComponents::ProgressRingControl::KEYWORDS +
            Controls::RufletComponents::CupertinoActivityIndicatorControl::KEYWORDS
          ).uniq.freeze
        end

        class SegmentedButtonControl < PlatformControl
          TYPE = "segmentedbutton".freeze
          WIRE = "SegmentedButton".freeze
          KEYWORDS = (
            Controls::RufletComponents::SegmentedButtonControl::KEYWORDS +
            Controls::RufletComponents::CupertinoSegmentedButtonControl::KEYWORDS +
            Controls::RufletComponents::CupertinoSlidingSegmentedButtonControl::KEYWORDS
          ).uniq.freeze
        end

        class ContextMenuControl < PlatformControl
          TYPE = "contextmenu".freeze
          WIRE = "ContextMenu".freeze
          KEYWORDS = (
            Controls::RufletComponents::ContextMenuControl::KEYWORDS +
            %i[actions adaptive enable_haptic_feedback]
          ).uniq.freeze

          def open(position: nil, timeout: 10, on_result: nil)
            args = {}
            args["position"] = stringify_hash_keys(position) unless position.nil?
            runtime_page&.invoke(self, "open", args: args, timeout: timeout, on_result: on_result)
          end

          private

          def validate_platform_props!(props) = require_control_prop!(props, :content)

          def stringify_hash_keys(value)
            return value.map { |item| stringify_hash_keys(item) } if value.is_a?(Array)
            if value.is_a?(Hash)
              return value.each_with_object({}) do |(key, child), result|
                result[key.to_s] = stringify_hash_keys(child)
              end
            end

            value
          end
        end

        class ContextMenuActionControl < PlatformControl
          TYPE = "contextmenuaction".freeze
          WIRE = "ContextMenuAction".freeze
          KEYWORDS = %i[
            adaptive align animate_align animate_margin animate_offset animate_opacity
            animate_position animate_rotation animate_scale animate_size aspect_ratio badge bottom
            checked col content data default destructive disabled expand expand_loose height icon key
            left margin mouse_cursor offset opacity right rotate rtl scale size_change_interval
            tooltip top trailing_icon value visible width on_animation_end on_click on_size_change
          ].freeze

          private

          def validate_platform_props!(props) = require_control_prop!(props, :content)
        end

        class ActionSheetControl < PlatformControl
          TYPE = "actionsheet".freeze
          WIRE = "ActionSheet".freeze
          KEYWORDS = Controls::RufletComponents::CupertinoActionSheetControl::KEYWORDS
        end

        class ActionSheetActionControl < PlatformControl
          TYPE = "actionsheetaction".freeze
          WIRE = "ActionSheetAction".freeze
          KEYWORDS = Controls::RufletComponents::CupertinoActionSheetActionControl::KEYWORDS

          private

          def validate_platform_props!(props) = require_control_prop!(props, :content)
        end

        class DatePickerControl < PlatformControl
          TYPE = "datepicker".freeze
          WIRE = "DatePicker".freeze
          KEYWORDS = (
            Controls::RufletComponents::DatePickerControl::KEYWORDS +
            Controls::RufletComponents::CupertinoDatePickerControl::KEYWORDS
          ).uniq.freeze

          private

          def normalize_platform_prop(key, value)
            return value unless %i[value first_date last_date current_date].include?(key)

            Ruflet::Protocol.date_time(value)
          end
        end

        class PickerControl < PlatformControl
          TYPE = "picker".freeze
          WIRE = "Picker".freeze
          KEYWORDS = Controls::RufletComponents::CupertinoPickerControl::KEYWORDS
        end

        class TimerPickerControl < PlatformControl
          TYPE = "timerpicker".freeze
          WIRE = "TimerPicker".freeze
          KEYWORDS = Controls::RufletComponents::CupertinoTimerPickerControl::KEYWORDS
        end

        class DropdownControl < PlatformControl
          TYPE = "dropdown".freeze
          WIRE = "Dropdown".freeze
          KEYWORDS = (
            Controls::RufletComponents::DropdownControl::KEYWORDS +
            Controls::RufletComponents::Dropdown2Control::KEYWORDS
          ).uniq.freeze
        end
      end

      CANONICAL_CLASS_MAP = {
        %w[button elevated_button elevatedbutton] => Components::ButtonControl,
        %w[filled_button filledbutton] => Components::FilledButtonControl,
        %w[filled_tonal_button filledtonalbutton] => Components::FilledTonalButtonControl,
        %w[outlined_button outlinedbutton] => Components::OutlinedButtonControl,
        %w[text_button textbutton] => Components::TextButtonControl,
        %w[text_field textfield] => Components::TextFieldControl,
        %w[checkbox] => Components::CheckboxControl,
        %w[radio] => Components::RadioControl,
        %w[slider] => Components::SliderControl,
        %w[switch] => Components::SwitchControl,
        %w[alert_dialog alertdialog] => Components::AlertDialogControl,
        %w[bottom_sheet bottomsheet] => Components::BottomSheetControl,
        %w[app_bar appbar] => Components::AppBarControl,
        %w[list_tile listtile] => Components::ListTileControl,
        %w[navigation_bar navigationbar] => Components::NavigationBarControl,
        %w[progress_ring progressring] => Components::ProgressRingControl,
        %w[segmented_button segmentedbutton] => Components::SegmentedButtonControl,
        %w[context_menu contextmenu] => Components::ContextMenuControl,
        %w[context_menu_action contextmenuaction] => Components::ContextMenuActionControl,
        %w[action_sheet actionsheet] => Components::ActionSheetControl,
        %w[action_sheet_action actionsheetaction] => Components::ActionSheetActionControl,
        %w[date_picker datepicker] => Components::DatePickerControl,
        %w[picker] => Components::PickerControl,
        %w[timer_picker timerpicker] => Components::TimerPickerControl,
        %w[dropdown dropdown_m2 dropdownm2] => Components::DropdownControl,
      }.each_with_object({}) do |(names, klass), map|
        names.each { |name| map[name] = klass }
      end.freeze

      LEGACY_CLASS_MAP = {
        %w[cupertino_button cupertinobutton] => Controls::RufletComponents::CupertinoButtonControl,
        %w[cupertino_filled_button cupertinofilledbutton] => Controls::RufletComponents::CupertinoFilledButtonControl,
        %w[cupertino_tinted_button cupertinotintedbutton] => Controls::RufletComponents::CupertinoTintedButtonControl,
        %w[cupertino_text_field cupertinotextfield] => Controls::RufletComponents::CupertinoTextFieldControl,
        %w[cupertino_checkbox cupertinocheckbox] => Controls::RufletComponents::CupertinoCheckboxControl,
        %w[cupertino_radio cupertinoradio] => Controls::RufletComponents::CupertinoRadioControl,
        %w[cupertino_slider cupertinoslider] => Controls::RufletComponents::CupertinoSliderControl,
        %w[cupertino_switch cupertinoswitch] => Controls::RufletComponents::CupertinoSwitchControl,
        %w[cupertino_alert_dialog cupertinoalertdialog] => Controls::RufletComponents::CupertinoAlertDialogControl,
        %w[cupertino_bottom_sheet cupertinobottomsheet] => Controls::RufletComponents::CupertinoBottomSheetControl,
        %w[cupertino_app_bar cupertinoappbar] => Controls::RufletComponents::CupertinoAppBarControl,
        %w[cupertino_list_tile cupertinolisttile] => Controls::RufletComponents::CupertinoListTileControl,
        %w[cupertino_navigation_bar cupertinonavigationbar] => Controls::RufletComponents::CupertinoNavigationBarControl,
        %w[cupertino_activity_indicator cupertinoactivityindicator] => Controls::RufletComponents::CupertinoActivityIndicatorControl,
        %w[cupertino_segmented_button cupertinosegmentedbutton] => Controls::RufletComponents::CupertinoSegmentedButtonControl,
        %w[cupertino_sliding_segmented_button cupertinoslidingsegmentedbutton] => Controls::RufletComponents::CupertinoSlidingSegmentedButtonControl,
        %w[cupertino_context_menu cupertinocontextmenu] => Controls::RufletComponents::CupertinoContextMenuControl,
        %w[cupertino_context_menu_action cupertinocontextmenuaction] => Controls::RufletComponents::CupertinoContextMenuActionControl,
        %w[cupertino_action_sheet cupertinoactionsheet] => Controls::RufletComponents::CupertinoActionSheetControl,
        %w[cupertino_action_sheet_action cupertinoactionsheetaction] => Controls::RufletComponents::CupertinoActionSheetActionControl,
        %w[cupertino_date_picker cupertinodatepicker] => Controls::RufletComponents::CupertinoDatePickerControl,
        %w[cupertino_picker cupertinopicker] => Controls::RufletComponents::CupertinoPickerControl,
        %w[cupertino_timer_picker cupertinotimerpicker] => Controls::RufletComponents::CupertinoTimerPickerControl,
        %w[cupertino_dialog_action cupertinodialogaction] => Controls::RufletComponents::CupertinoDialogActionControl,
        %w[popup_menu_item popupmenuitem] => Controls::RufletComponents::PopupMenuItemControl
      }.each_with_object({}) do |(names, klass), map|
        names.each { |name| map[name] = klass }
      end.freeze

      CLASS_MAP = CANONICAL_CLASS_MAP.merge(LEGACY_CLASS_MAP).freeze

      TYPE_MAP = CLASS_MAP.each_with_object({}) do |(name, klass), map|
        map[name] = klass::WIRE
      end.freeze
    end
  end
end
