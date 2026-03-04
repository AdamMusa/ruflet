# frozen_string_literal: true

module RufletStudio
  module SectionsMedia
    def build_animation(page, status)
      size = 15
      gap = 3
      duration = 2000

      c1 = "#f06595"
      c2 = "#f59f00"
      c3 = "#69db7c"
      c4 = "#7950f2"

      all_colors = [
        "#ffe066", "#ffd43b", "#4dabf7", "#8d6e63", "#0ca678",
        "#ff922b", "#15aabf", "#3b5bdb", "#ffd8a8", "#faa2c1",
        "#fa5252", "#69db7c", "#8ce99a", "#20c997", "#4dabf7"
      ]

      parts = [
        # R
        [0, 0, c1], [0, 1, c1], [0, 2, c1], [0, 3, c1], [0, 4, c1],
        [1, 0, c1], [2, 0, c1], [3, 0, c1], [4, 0, c1],
        [1, 2, c1], [2, 2, c1],
        [1, 4, c1], [2, 4, c1],
        [3, 3, c1], [4, 4, c1],
        # U
        [6, 0, c2], [7, 0, c2], [8, 0, c2], [9, 0, c2],
        [6, 4, c2], [7, 4, c2], [8, 4, c2], [9, 4, c2],
        [10, 1, c2], [10, 2, c2], [10, 3, c2],
        # F (offset +12)
        [12, 0, c1], [12, 1, c1], [12, 2, c1], [12, 3, c1], [12, 4, c1],
        [13, 0, c1], [13, 2, c1],
        [14, 0, c1],
        # L (offset +12)
        [16, 0, c2], [16, 1, c2], [16, 2, c2], [16, 3, c2], [16, 4, c2],
        [17, 4, c2], [18, 4, c2],
        # E (offset +12)
        [20, 0, c3], [21, 0, c3], [22, 0, c3],
        [20, 1, c3], [20, 2, c3], [21, 2, c3], [22, 2, c3],
        [20, 3, c3], [20, 4, c3], [21, 4, c3], [22, 4, c3],
        # T (offset +12)
        [24, 0, c4], [25, 0, c4], [26, 0, c4],
        [25, 1, c4], [25, 2, c4], [25, 3, c4], [25, 4, c4]
      ]

      max_x = parts.map { |p| p[0] }.max || 0
      max_y = parts.map { |p| p[1] }.max || 0
      width = (max_x + 2) * (size + gap)
      height = (max_y + 2) * (size + gap)

      scattered = true

      parts_controls = parts.map do |_x, _y, _color|
        container(
          animate: duration,
          animate_position: duration,
          animate_rotation: duration,
          left: rand(width),
          top: rand(height),
          bgcolor: all_colors.sample,
          width: rand((size / 2).to_i..(size * 3)),
          height: rand((size / 2).to_i..(size * 3)),
          border_radius: rand(0..(size / 2)),
          rotate: rand(0..90) * Math::PI / 180
        )
      end

      canvas = stack(
        width: width,
        height: height,
        animate_scale: duration,
        animate_opacity: duration,
        scale: 5,
        opacity: 0.3
      )
      canvas.children.replace(parts_controls)

      btn = button(text: "Go!")
      toggle = lambda do
        scattered = !scattered
        page.update(canvas, scale: scattered ? 5 : 1, opacity: scattered ? 0.3 : 1)
        parts_controls.each_with_index do |control, idx|
          px, py, pcolor = parts[idx]
          if scattered
            page.update(
              control,
              left: rand(width),
              top: rand(height),
              bgcolor: all_colors.sample,
              width: rand((size / 2).to_i..(size * 3)),
              height: rand((size / 2).to_i..(size * 3)),
              border_radius: rand(0..(size / 2)),
              rotate: rand(0..90) * Math::PI / 180
            )
          else
            page.update(
              control,
              left: px * (size + gap),
              top: py * (size + gap),
              bgcolor: pcolor,
              width: size,
              height: size,
              border_radius: 5,
              rotate: 0
            )
          end
        end
        page.update(btn, text: scattered ? "Go!" : "Again!")
      end
      btn.on(:click) { |_e| toggle.call }

      container(
        alignment: "center",
        content: column(
          alignment: "center",
          horizontal_alignment: "center",
          tight: true,
          controls: [canvas, btn]
        )
      )
    end
  end
end
