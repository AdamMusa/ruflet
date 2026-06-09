# frozen_string_literal: true

module Showcase
  module SectionsMedia
    def build_animation(page, status)
      random = Random.new
      scattered = true
      size = 14
      gap = 4
      duration = 2_000
      letter_gap = 2
      colors = ["#ec5f94", "#ffa000", "#5bd46f", "#7c4dff", "#42a5f5", "#ffd43b"]
      scatter_colors = [
        "#ffd54f", "#40c4ff", "#ff7043", "#66bb6a", "#ab47bc",
        "#26a69a", "#5c7cfa", "#f06292", "#ffca28", "#4dd0e1"
      ]
      letter_grids = {
        "R" => ["1110", "1001", "1110", "1010", "1001"],
        "u" => ["1001", "1001", "1001", "1001", "1111"],
        "f" => ["1111", "1000", "1110", "1000", "1000"],
        "l" => ["1000", "1000", "1000", "1000", "1111"],
        "e" => ["1111", "1000", "1110", "1000", "1111"],
        "t" => ["1111", "0100", "0100", "0100", "0100"]
      }
      letters = ["R", "u", "f", "l", "e", "t"]

      parts = []
      cursor = 0
      letters.each_with_index do |letter, letter_index|
        rows = letter_grids.fetch(letter)
        rows.each_with_index do |row, y|
          row.chars.each_with_index do |cell, x|
            next unless cell == "1"

            parts << {
              left: (cursor + x) * (size + gap),
              top: y * (size + gap),
              color: colors[letter_index]
            }
          end
        end
        cursor += rows.first.length + letter_gap
      end

      width = cursor * (size + gap)
      height = 5 * (size + gap)
      scatter_props = lambda do
        {
          left: random.rand(0..width),
          top: random.rand(0..(height * 3)),
          width: random.rand((size / 2)..(size * 3)),
          height: random.rand((size / 2)..(size * 3)),
          bgcolor: scatter_colors.sample(random: random),
          border_radius: random.rand(0..(size / 2)),
          rotate: random.rand(0..90) * Math::PI / 180.0
        }
      end
      settle_props = lambda do |part|
        {
          left: part.fetch(:left),
          top: part.fetch(:top),
          width: size,
          height: size,
          bgcolor: part.fetch(:color),
          border_radius: 4,
          rotate: 0
        }
      end

      cells = parts.map do |part|
        container(
          **scatter_props.call,
          animate: duration,
          animate_position: duration,
          animate_rotation: duration
        )
      end

      canvas = stack(
        width: width,
        height: height * 3,
        animate_scale: duration,
        animate_opacity: duration,
        scale: 3.4,
        opacity: 0.32,
        children: cells
      )

      btn = button(content: text(value: "Go!"))
      btn.on(:click) do |_e|
        scattered = !scattered
        cells.each_with_index do |cell, index|
          page.update(cell, **(scattered ? scatter_props.call : settle_props.call(parts[index])))
        end
        page.update(canvas, scale: scattered ? 3.4 : 1, opacity: scattered ? 0.32 : 1)
        page.update(btn, content: text(value: scattered ? "Go!" : "Again!"))
        page.update(status, value: scattered ? "Ruflet scattered." : "Ruflet assembled.")
      end

      container(
        expand: true,
        alignment: "center",
        content: column(
          alignment: "center",
          horizontal_alignment: "center",
          tight: true,
          spacing: 16,
          children: [canvas, btn]
        )
      )
    end
  end
end
