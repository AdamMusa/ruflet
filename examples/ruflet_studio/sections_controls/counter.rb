# frozen_string_literal: true

module RufletStudio
  module SectionsControls
    def build_counter(page, status)
      count = 0
      value = text(value: count.to_s, style: { size: 28 })

      container(
        width: 320,
        padding: 12,
        border_radius: 12,
        bgcolor: color_panel(page),
        content: column(
          spacing: 12,
          children: [
            status,
            row(alignment: "center", children: [value]),
            row(
              alignment: "center",
              spacing: 10,
              children: [
                elevated_button(
                  width: 120,
                  content: text(value: "-1"),
                  on_click: ->(_e) {
                    count -= 1
                    page.update(value, value: count.to_s)
                    page.update(status, value: "Counter: #{count}")
                  }
                ),
                elevated_button(
                  width: 120,
                  content: text(value: "+1"),
                  on_click: ->(_e) {
                    count += 1
                    page.update(value, value: count.to_s)
                    page.update(status, value: "Counter: #{count}")
                  }
                )
              ]
            ),
          ]
        )
      )
    end
  end
end
