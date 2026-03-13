require "ruflet"
Ruflet.run do |page|
  page.title = "Counter Demo"
  count = 0
  count_text = nil
  count_text ||= text(value: count.to_s, style: { size: 40 })
  page.add(
    container(
      expand: true,
      alignment: Ruflet::MainAxisAlignment::CENTER,
      content: column(
        alignment: Ruflet::MainAxisAlignment::CENTER,
        horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
        children: [
          text(value: "You have pushed the button this many times:"),
          icon(icon: Ruflet::MaterialIcons::ADD),
          count_text
        ]
      )
    ),
    floating_action_button: fab(
      icon(icon: Ruflet::MaterialIcons::ADD),
      on_click: ->(_e) do
        count += 1
        page.update(count_text, value: count.to_s)
      end
    )
  )
end
