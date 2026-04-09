require "ruflet"
Ruflet.run do |page|
  page.title = "Ruflet demo"
  count = 0
  count_text = text(count.to_s, style: {size: 40})
  page.add(
    container(
      expand: true,
      alignment: Ruflet::MainAxisAlignment::CENTER,
      content: column(
        alignment: Ruflet::MainAxisAlignment::CENTER,
        horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
        children: [
          text("A self-contained ruflet app up and running!"),
          count_text
        ]
      )
    ),
    appbar: app_bar(title: text("Ruflet demo", style: { size: 18 })),
    floating_action_button: FloatingActionButton(
      icon: Ruflet::MaterialIcons::ADD,
      on_click: ->(_e) do
        count += 1
        page.update(count_text, value: count.to_s)
      end
    )
  )
end
