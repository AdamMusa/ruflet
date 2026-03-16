# frozen_string_literal: true

module RufletStudio
  module SectionsControls
    DIGITS = %w[0 1 2 3 4 5 6 7 8 9].freeze

    def build_calculator(page, status)
      display = calculator_display(page)
      container(
        width: 420,
        padding: 12,
        border_radius: 12,
        bgcolor: color_panel(page),
        content: column(
          spacing: 12,
          children: [
            status,
            container(height: 24),
            row(alignment: "end", children: [display]),
            container(height: 20),
            calculator_keypad_row(page, display, status, "BS", "AC", "%", "/"),
            calculator_keypad_row(page, display, status, "7", "8", "9", "x"),
            calculator_keypad_row(page, display, status, "4", "5", "6", "-"),
            calculator_keypad_row(page, display, status, "1", "2", "3", "+"),
            calculator_keypad_row(page, display, status, "+/-", "0", ".", "=")
          ]
        )
      )
    end

    def calculator_state
      @calculator_state ||= { display: "0", operand: nil, operator: nil, start_new_value: false }
    end

    def calculator_display(page)
      @calculator_display = text(
        value: calculator_state[:display],
        text_align: "right",
        style: { size: 84, color: color_text(page) }
      )
    end

    def calculator_keypad_row(page, display, status, *labels)
      row(
        alignment: "center",
        spacing: 6,
        children: labels.map do |label|
          elevated_button(
            content: text(value: label),
            width: 78,
            height: 65,
            color: calculator_key_text_color(page, label),
            bgcolor: calculator_key_bg(page, label),
            on_click: ->(e) { calculator_handle_input(label, e, page, display, status) }
          )
        end
      )
    end

    def calculator_key_bg(page, label)
      %w[/ x - + =].include?(label) ? color_accent(page) : color_surface(page)
    end

    def calculator_key_text_color(page, label)
      %w[/ x - + =].include?(label) ? "#FFFFFF" : color_text(page)
    end

    def calculator_handle_input(label, event, page, display, status)
      if DIGITS.include?(label)
        calculator_on_digit(label)
      elsif label == "."
        calculator_on_decimal
      elsif %w[x / - +].include?(label)
        calculator_on_operator(label)
      elsif label == "="
        calculator_on_equals
      elsif label == "AC"
        calculator_reset
      elsif label == "+/-"
        calculator_on_toggle_sign
      elsif label == "%"
        calculator_on_percent
      elsif label == "BS"
        calculator_on_backspace
      end

      page.update(display, value: calculator_state[:display])
      page.update(status, value: "Calculator result: #{calculator_state[:display]}") if label == "="
      event
    end

    def calculator_on_digit(digit)
      if calculator_state[:start_new_value] || calculator_state[:display] == "Error"
        calculator_state[:display] = digit
        calculator_state[:start_new_value] = false
        return
      end

      calculator_state[:display] = (calculator_state[:display] == "0" ? digit : "#{calculator_state[:display]}#{digit}")
    end

    def calculator_on_decimal
      if calculator_state[:start_new_value] || calculator_state[:display] == "Error"
        calculator_state[:display] = "0."
        calculator_state[:start_new_value] = false
        return
      end

      calculator_state[:display] += "." unless calculator_state[:display].include?(".")
    end

    def calculator_on_operator(next_operator)
      if calculator_state[:operator] && !calculator_state[:start_new_value]
        calculator_apply_calculation
        return if calculator_state[:display] == "Error"
      else
        calculator_state[:operand] = calculator_to_number(calculator_state[:display])
      end

      calculator_state[:operator] = next_operator
      calculator_state[:start_new_value] = true
    end

    def calculator_on_equals
      return unless calculator_state[:operator]

      calculator_apply_calculation
      calculator_state[:operator] = nil if calculator_state[:display] != "Error"
    end

    def calculator_on_toggle_sign
      return if calculator_state[:display] == "0" || calculator_state[:display] == "Error"

      calculator_state[:display] = if calculator_state[:display].start_with?("-")
                                     calculator_state[:display][1..]
                                   else
                                     "-#{calculator_state[:display]}"
                                   end
    end

    def calculator_on_percent
      return if calculator_state[:display] == "Error"

      calculator_state[:display] = calculator_format_number(calculator_to_number(calculator_state[:display]) / 100.0)
      calculator_state[:start_new_value] = true
    end

    def calculator_on_backspace
      return if calculator_state[:display] == "Error"

      if calculator_state[:display].length <= 1 || (calculator_state[:display].length == 2 && calculator_state[:display].start_with?("-"))
        calculator_state[:display] = "0"
        return
      end

      calculator_state[:display] = calculator_state[:display][0...-1]
    end

    def calculator_apply_calculation
      right = calculator_to_number(calculator_state[:display])
      result = case calculator_state[:operator]
               when "+"
                 calculator_state[:operand] + right
               when "-"
                 calculator_state[:operand] - right
               when "x"
                 calculator_state[:operand] * right
               when "/"
                 return calculator_show_error if right.zero?

                 calculator_state[:operand] / right
               end

      calculator_state[:display] = calculator_format_number(result)
      calculator_state[:operand] = calculator_to_number(calculator_state[:display])
      calculator_state[:start_new_value] = true
    end

    def calculator_to_number(value)
      Float(value)
    rescue StandardError
      0.0
    end

    def calculator_format_number(value)
      number = value.to_f
      return number.to_i.to_s if number == number.to_i

      number.to_s.sub(/\.?0+\z/, "")
    end

    def calculator_show_error
      calculator_state[:display] = "Error"
      calculator_state[:operator] = nil
      calculator_state[:operand] = nil
      calculator_state[:start_new_value] = true
    end

    def calculator_reset
      calculator_state[:display] = "0"
      calculator_state[:operand] = nil
      calculator_state[:operator] = nil
      calculator_state[:start_new_value] = false
    end
  end
end
