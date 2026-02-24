require "ruby_native"

class MainApp < RubyNative::App
  def view(page)
    app_name = "RubyNative Demo"
    page.title = app_name

    body = page.column(
      expand: true,
      alignment: RubyNative::MainAxisAlignment::CENTER,
      horizontal_alignment: RubyNative::CrossAxisAlignment::CENTER,
      spacing: 8
    ) do
      text value: "Hello World!", size: 32
      text value: "Scaffold-style page: app bar, body, and FAB", size: 12, color: "#4d4c57"
    end

    page.add(
      body,
      appbar: page.app_bar(
        bgcolor: "#d9d7db",
        color: "#232329",
        title: page.text(value: app_name, size: 18)
      ),
      floating_action_button: page.fab("+", bgcolor: "#232329", color: "#FFFFFF", on_click: ->(_e) {})
    )
  end
end

MainApp.new.run
