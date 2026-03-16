# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SemanticsControl < Ruflet::Control
          TYPE = "semantics".freeze
          WIRE = "Semantics".freeze

          def initialize(id: nil, badge: nil, button: nil, checked: nil, col: nil, container: nil, content: nil, current_value_length: nil, data: nil, decreased_value: nil, disabled: nil, exclude_semantics: nil, expand: nil, expand_loose: nil, expanded: nil, focus: nil, focusable: nil, header: nil, heading_level: nil, hidden: nil, hint_text: nil, image: nil, increased_value: nil, key: nil, label: nil, link: nil, live_region: nil, max_value_length: nil, mixed: nil, multiline: nil, obscured: nil, opacity: nil, read_only: nil, rtl: nil, selected: nil, slider: nil, textfield: nil, toggled: nil, tooltip: nil, value: nil, visible: nil, on_copy: nil, on_cut: nil, on_decrease: nil, on_did_gain_accessibility_focus: nil, on_did_lose_accessibility_focus: nil, on_dismiss: nil, on_double_tap: nil, on_increase: nil, on_long_press: nil, on_long_press_hint_text: nil, on_move_cursor_backward_by_character: nil, on_move_cursor_forward_by_character: nil, on_paste: nil, on_scroll_down: nil, on_scroll_left: nil, on_scroll_right: nil, on_scroll_up: nil, on_set_text: nil, on_tap: nil, on_tap_hint_text: nil)
            props = {}
            props[:badge] = badge unless badge.nil?
            props[:button] = button unless button.nil?
            props[:checked] = checked unless checked.nil?
            props[:col] = col unless col.nil?
            props[:container] = container unless container.nil?
            props[:content] = content unless content.nil?
            props[:current_value_length] = current_value_length unless current_value_length.nil?
            props[:data] = data unless data.nil?
            props[:decreased_value] = decreased_value unless decreased_value.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:exclude_semantics] = exclude_semantics unless exclude_semantics.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:expanded] = expanded unless expanded.nil?
            props[:focus] = focus unless focus.nil?
            props[:focusable] = focusable unless focusable.nil?
            props[:header] = header unless header.nil?
            props[:heading_level] = heading_level unless heading_level.nil?
            props[:hidden] = hidden unless hidden.nil?
            props[:hint_text] = hint_text unless hint_text.nil?
            props[:image] = image unless image.nil?
            props[:increased_value] = increased_value unless increased_value.nil?
            props[:key] = key unless key.nil?
            props[:label] = label unless label.nil?
            props[:link] = link unless link.nil?
            props[:live_region] = live_region unless live_region.nil?
            props[:max_value_length] = max_value_length unless max_value_length.nil?
            props[:mixed] = mixed unless mixed.nil?
            props[:multiline] = multiline unless multiline.nil?
            props[:obscured] = obscured unless obscured.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:read_only] = read_only unless read_only.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:selected] = selected unless selected.nil?
            props[:slider] = slider unless slider.nil?
            props[:textfield] = textfield unless textfield.nil?
            props[:toggled] = toggled unless toggled.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:value] = value unless value.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_copy] = on_copy unless on_copy.nil?
            props[:on_cut] = on_cut unless on_cut.nil?
            props[:on_decrease] = on_decrease unless on_decrease.nil?
            props[:on_did_gain_accessibility_focus] = on_did_gain_accessibility_focus unless on_did_gain_accessibility_focus.nil?
            props[:on_did_lose_accessibility_focus] = on_did_lose_accessibility_focus unless on_did_lose_accessibility_focus.nil?
            props[:on_dismiss] = on_dismiss unless on_dismiss.nil?
            props[:on_double_tap] = on_double_tap unless on_double_tap.nil?
            props[:on_increase] = on_increase unless on_increase.nil?
            props[:on_long_press] = on_long_press unless on_long_press.nil?
            props[:on_long_press_hint_text] = on_long_press_hint_text unless on_long_press_hint_text.nil?
            props[:on_move_cursor_backward_by_character] = on_move_cursor_backward_by_character unless on_move_cursor_backward_by_character.nil?
            props[:on_move_cursor_forward_by_character] = on_move_cursor_forward_by_character unless on_move_cursor_forward_by_character.nil?
            props[:on_paste] = on_paste unless on_paste.nil?
            props[:on_scroll_down] = on_scroll_down unless on_scroll_down.nil?
            props[:on_scroll_left] = on_scroll_left unless on_scroll_left.nil?
            props[:on_scroll_right] = on_scroll_right unless on_scroll_right.nil?
            props[:on_scroll_up] = on_scroll_up unless on_scroll_up.nil?
            props[:on_set_text] = on_set_text unless on_set_text.nil?
            props[:on_tap] = on_tap unless on_tap.nil?
            props[:on_tap_hint_text] = on_tap_hint_text unless on_tap_hint_text.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
