require "ruflet"

class MainApp < Ruflet::App
  def initialize
    super
    @count = 0
  end

  def view(page)
    page.title = "Counter Demo"
    page.vertical_alignment = Ruflet::MainAxisAlignment::CENTER
    page.horizontal_alignment = Ruflet::CrossAxisAlignment::CENTER
    count_text = page.text(value: @count.to_s, size: 40)

    page.add(
      page.container(
        expand: true,
        padding: 24,
        content: page.column(
          expand: true,
          alignment: Ruflet::MainAxisAlignment::CENTER,
          horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
          spacing: 12,
          controls: [
            page.text(value: "You have pushed the button this many times:"),
            count_text
          ]
        )
      ),
      appbar: page.app_bar(
        title: page.text(value: "Counter Demo")
      ),
      floating_action_button: page.fab(
        page.icon(icon: Ruflet::MaterialIcons::ADD),
        on_click: ->(_e) {
          @count += 1
          page.update(count_text, value: @count.to_s)
        }
      )
    )
  end
end

MainApp.new.run