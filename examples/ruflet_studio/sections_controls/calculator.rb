# frozen_string_literal: true

module RufletStudio
  module SectionsControls
    def build_calculator(page, status)
      display = page.text(value: "0", color: "#ffffff", size: 20)
      calc_state = { display: "0", operand1: 0.0, operator: "+", new_operand: true }

      on_button = lambda do |label|
        if calc_state[:display] == "Error" || label == "AC"
          calc_state[:display] = "0"
          calc_state[:operand1] = 0.0
          calc_state[:operator] = "+"
          calc_state[:new_operand] = true
          page.update(display, value: "0")
          return
        end

        if label.match?(/^[0-9.]$/)
          if calc_state[:display] == "0" || calc_state[:new_operand]
            calc_state[:display] = label
            calc_state[:new_operand] = false
          else
            calc_state[:display] += label
          end
          page.update(display, value: calc_state[:display])
          return
        end

        if ["+", "-", "*", "/"].include?(label)
          val = compute(calc_state[:operand1], calc_state[:display], calc_state[:operator])
          calc_state[:display] = val.to_s
          calc_state[:operator] = label
          calc_state[:operand1] = val == "Error" ? 0.0 : val.to_f
          calc_state[:new_operand] = true
          page.update(display, value: calc_state[:display])
          return
        end

        if label == "="
          val = compute(calc_state[:operand1], calc_state[:display], calc_state[:operator])
          calc_state[:display] = val.to_s
          calc_state[:operand1] = 0.0
          calc_state[:operator] = "+"
          calc_state[:new_operand] = true
          page.update(display, value: calc_state[:display])
          page.update(status, value: "Calculator result: #{calc_state[:display]}")
          return
        end

        if label == "%"
          calc_state[:display] = (calc_state[:display].to_f / 100).to_s
          calc_state[:operand1] = 0.0
          calc_state[:operator] = "+"
          calc_state[:new_operand] = true
          page.update(display, value: calc_state[:display])
        end
      end

      make_btn = lambda do |label, bgcolor, color, expand|
        page.button(
          text: label,
          expand: expand,
          bgcolor: bgcolor,
          color: color,
          on_click: ->(_e) { on_button.call(label) }
        )
      end

      page.container(
        width: 320,
        bgcolor: "#000000",
        border_radius: 20,
        padding: 16,
        content: page.column(
          spacing: 8,
          controls: [
            page.row(controls: [display], alignment: "end"),
            page.row(controls: [
              make_btn.call("AC", "#ced4da", "#000000", 1),
              make_btn.call("+/-", "#ced4da", "#000000", 1),
              make_btn.call("%", "#ced4da", "#000000", 1),
              make_btn.call("/", "#f76707", "#ffffff", 1)
            ]),
            page.row(controls: [
              make_btn.call("7", "#495057", "#ffffff", 1),
              make_btn.call("8", "#495057", "#ffffff", 1),
              make_btn.call("9", "#495057", "#ffffff", 1),
              make_btn.call("*", "#f76707", "#ffffff", 1)
            ]),
            page.row(controls: [
              make_btn.call("4", "#495057", "#ffffff", 1),
              make_btn.call("5", "#495057", "#ffffff", 1),
              make_btn.call("6", "#495057", "#ffffff", 1),
              make_btn.call("-", "#f76707", "#ffffff", 1)
            ]),
            page.row(controls: [
              make_btn.call("1", "#495057", "#ffffff", 1),
              make_btn.call("2", "#495057", "#ffffff", 1),
              make_btn.call("3", "#495057", "#ffffff", 1),
              make_btn.call("+", "#f76707", "#ffffff", 1)
            ]),
            page.row(controls: [
              make_btn.call("0", "#495057", "#ffffff", 2),
              make_btn.call(".", "#495057", "#ffffff", 1),
              make_btn.call("=", "#f76707", "#ffffff", 1)
            ])
          ]
        )
      )
    end
  end
end
