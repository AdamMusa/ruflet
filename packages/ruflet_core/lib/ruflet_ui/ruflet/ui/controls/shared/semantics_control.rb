# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SemanticsControl < Ruflet::Control
          TYPE = "semantics".freeze
          WIRE = "Semantics".freeze

          KEYWORDS = [:badge, :button, :checked, :col, :container, :content, :current_value_length, :data, :decreased_value, :disabled, :exclude_semantics, :expand, :expand_loose, :expanded, :focus, :focusable, :header, :heading_level, :hidden, :hint_text, :image, :increased_value, :key, :label, :link, :live_region, :max_value_length, :mixed, :multiline, :obscured, :opacity, :read_only, :rtl, :selected, :slider, :textfield, :toggled, :tooltip, :value, :visible, :on_copy, :on_cut, :on_decrease, :on_did_gain_accessibility_focus, :on_did_lose_accessibility_focus, :on_dismiss, :on_double_tap, :on_increase, :on_long_press, :on_long_press_hint_text, :on_move_cursor_backward_by_character, :on_move_cursor_forward_by_character, :on_paste, :on_scroll_down, :on_scroll_left, :on_scroll_right, :on_scroll_up, :on_set_text, :on_tap, :on_tap_hint_text].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            badge = props[:badge]
            button = props[:button]
            checked = props[:checked]
            col = props[:col]
            container = props[:container]
            content = props[:content]
            current_value_length = props[:current_value_length]
            data = props[:data]
            decreased_value = props[:decreased_value]
            disabled = props[:disabled]
            exclude_semantics = props[:exclude_semantics]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            expanded = props[:expanded]
            focus = props[:focus]
            focusable = props[:focusable]
            header = props[:header]
            heading_level = props[:heading_level]
            hidden = props[:hidden]
            hint_text = props[:hint_text]
            image = props[:image]
            increased_value = props[:increased_value]
            key = props[:key]
            label = props[:label]
            link = props[:link]
            live_region = props[:live_region]
            max_value_length = props[:max_value_length]
            mixed = props[:mixed]
            multiline = props[:multiline]
            obscured = props[:obscured]
            opacity = props[:opacity]
            read_only = props[:read_only]
            rtl = props[:rtl]
            selected = props[:selected]
            slider = props[:slider]
            textfield = props[:textfield]
            toggled = props[:toggled]
            tooltip = props[:tooltip]
            value = props[:value]
            visible = props[:visible]
            on_copy = props[:on_copy]
            on_cut = props[:on_cut]
            on_decrease = props[:on_decrease]
            on_did_gain_accessibility_focus = props[:on_did_gain_accessibility_focus]
            on_did_lose_accessibility_focus = props[:on_did_lose_accessibility_focus]
            on_dismiss = props[:on_dismiss]
            on_double_tap = props[:on_double_tap]
            on_increase = props[:on_increase]
            on_long_press = props[:on_long_press]
            on_long_press_hint_text = props[:on_long_press_hint_text]
            on_move_cursor_backward_by_character = props[:on_move_cursor_backward_by_character]
            on_move_cursor_forward_by_character = props[:on_move_cursor_forward_by_character]
            on_paste = props[:on_paste]
            on_scroll_down = props[:on_scroll_down]
            on_scroll_left = props[:on_scroll_left]
            on_scroll_right = props[:on_scroll_right]
            on_scroll_up = props[:on_scroll_up]
            on_set_text = props[:on_set_text]
            on_tap = props[:on_tap]
            on_tap_hint_text = props[:on_tap_hint_text]
            exclude_semantics = false if exclude_semantics.nil?

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
