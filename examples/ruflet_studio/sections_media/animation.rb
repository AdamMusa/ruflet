# frozen_string_literal: true

module RufletStudio
  module SectionsMedia
    def build_animation(page, status)
      animation_box = page.container(
        width: 60,
        height: 60,
        bgcolor: "#ff6b6b",
        border_radius: 12,
        left: 0,
        top: 0,
        animate_position: 800,
        animate_rotation: 800,
        animate_scale: 800,
        animate_opacity: 800
      )

      animation_state = { moved: false }

      page.column(
        spacing: 8,
        controls: [
          status,
          page.stack(width: 240, height: 140, controls: [animation_box]),
          page.button(
            text: "Animate",
            on_click: ->(_e) {
              animation_state[:moved] = !animation_state[:moved]
              if animation_state[:moved]
                page.update(animation_box, left: 140, top: 60, rotate: 0.5, scale: 1.4, opacity: 0.6)
              else
                page.update(animation_box, left: 0, top: 0, rotate: 0, scale: 1.0, opacity: 1.0)
              end
            }
          )
        ]
      )
    end
  end
end
