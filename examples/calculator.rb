require "ruflet"

class CalculatorApp < Ruflet::App
  DIGITS = %w[0 1 2 3 4 5 6 7 8 9].freeze

  def initialize
    super
    reset
  end

  def view(page)
    page.title = "Calculator"
    page.bgcolor = "#000000"

    @display_control = page.text(
      value: @display,
      text_align: "right",
      size: 84,
      color: "#FFFFFF"
    )

    page.add(
      page.container(
        expand: true,
        bgcolor: "#000000",
        padding: 12,
        content: page.column(
          expand: true,
          spacing: 12,
          controls: [
            page.container(height: 24),
            page.row(alignment: "end", controls: [@display_control]),

            # pushes keypad toward bottom
            page.container(expand: true),

            # gap between result and keyboard
            page.container(height: 20),

            row(page, "BS", "AC", "%", "/"),
            row(page, "7", "8", "9", "x"),
            row(page, "4", "5", "6", "-"),
            row(page, "1", "2", "3", "+"),
            row(page, "+/-", "0", ".", "=")
          ]
        )
      )
    )
  end

  private

  def row(page, *labels)
    page.row(
      alignment: "center",
      spacing: 10,
      controls: labels.map do |label|
        page.elevated_button(
          text: label,
          expand: true,
          height: 65,
          color: "#FFFFFF",
          bgcolor: key_bg(label),
          on_click: ->(e) { handle_input(label, e) }
        )
      end
    )
  end

  def key_bg(label)
    operator_label?(label) ? "#FF9F0A" : "#2C2C2E"
  end

  def handle_input(label, event)
    if DIGITS.include?(label)
      on_digit(label)
    elsif label == "."
      on_decimal
    elsif label == "x"
      on_operator("x")
    elsif label == "/"
      on_operator("/")
    elsif label == "-"
      on_operator("-")
    elsif label == "+"
      on_operator("+")
    elsif label == "="
      on_equals
    elsif label == "AC"
      reset
    elsif label == "+/-"
      on_toggle_sign
    elsif label == "%"
      on_percent
    elsif label == "BS"
      on_backspace
    end

    event.page.update(@display_control, value: @display)
  end

  def on_digit(digit)
    if @start_new_value || @display == "Error"
      @display = digit
      @start_new_value = false
      return
    end

    @display = (@display == "0" ? digit : "#{@display}#{digit}")
  end

  def on_decimal
    if @start_new_value || @display == "Error"
      @display = "0."
      @start_new_value = false
      return
    end

    @display += "." unless @display.include?(".")
  end

  def on_operator(next_operator)
    if @operator && !@start_new_value
      apply_calculation
      return if @display == "Error"
    else
      @operand = to_number(@display)
    end

    @operator = next_operator
    @start_new_value = true
  end

  def on_equals
    return unless @operator

    apply_calculation
    @operator = nil if @display != "Error"
  end

  def on_toggle_sign
    return if @display == "0" || @display == "Error"

    @display = @display.start_with?("-") ? @display[1..] : "-#{@display}"
  end

  def on_percent
    return if @display == "Error"

    @display = format_number(to_number(@display) / 100.0)
    @start_new_value = true
  end

  def on_backspace
    return if @display == "Error"

    if @display.length <= 1 || (@display.length == 2 && @display.start_with?("-"))
      @display = "0"
      return
    end

    @display = @display[0...-1]
  end

  def apply_calculation
    right = to_number(@display)
    result = case @operator
             when "+" then @operand + right
             when "-" then @operand - right
             when "x" then @operand * right
             when "/"
               return show_error if right.zero?

               @operand / right
             end

    @display = format_number(result)
    @operand = to_number(@display)
    @start_new_value = true
  end

  def to_number(value)
    Float(value)
  rescue StandardError
    0.0
  end

  def format_number(value)
    value = value.to_f
    return value.to_i.to_s if value == value.to_i

    value.to_s.sub(/\.?0+\z/, "")
  end

  def show_error
    @display = "Error"
    @operator = nil
    @operand = nil
    @start_new_value = true
  end

  def reset
    @display = "0"
    @operand = nil
    @operator = nil
    @start_new_value = false
  end

  def operator_label?(label)
    %w[/ x - + =].include?(label)
  end
end

CalculatorApp.new.run

