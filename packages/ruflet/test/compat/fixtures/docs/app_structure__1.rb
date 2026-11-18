# Docs example: content/docs/app_structure.md, line 26 (AdamMusa/ruflet_site 05dde18).
# Copied verbatim below this header; do not edit.
require "ruflet"

Ruflet.run do |page|
  count = 0
  label = text(value: "0", style: { size: 40 })

  page.add(
    column(
      children: [
        label,
        filled_button(
          content: text("Increment"),
          on_click: ->(_event) {
            count += 1
            page.update(label, value: count.to_s)
          }
        )
      ]
    )
  )
end
