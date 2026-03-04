# frozen_string_literal: true

module RufletStudio
  module SectionsControls
    def build_counter(page, status)
      count = 0
      value = text_field(value: count.to_s, text_align: "right", width: 80)

      row(
        spacing: 8,
        alignment: "center",
        controls: [
          icon_button(icon: "remove", on_click: ->(_e) {
            count -= 1
            page.update(value, value: count.to_s)
            page.update(status, value: "Counter: #{count}")
          }),
          value,
          icon_button(icon: "add", on_click: ->(_e) {
            count += 1
            page.update(value, value: count.to_s)
            page.update(status, value: "Counter: #{count}")
          })
        ]
      )
    end
  end
end
