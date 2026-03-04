require "ruflet"

class MainApp < Ruflet::App
  def initialize
    super
    @count = 0
  end

  def view(page)
    page.title = "Counter Demo"
    count_text = text(value: @count.to_s, size: 40)

    page.add(
      container(
        expand: true,
        padding: 24,
        content: column(
          expand: true,
          alignment: Ruflet::MainAxisAlignment::CENTER,
          horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
          spacing: 12,
          controls: [
            text(value: "You have pushed the button this many times:"),
            count_text
          ]
        )
      ),
      appbar: app_bar(
        title: text(value: "Counter Demo")
      ),
      floating_action_button: fab(
        icon(icon: Ruflet::MaterialIcons::ADD),
        on_click: ->(_e) {
          @count += 1
          page.update(count_text, value: @count.to_s)
        }
      )
    )
  end
end

MainApp.new.run