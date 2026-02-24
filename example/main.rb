require "ruby_native"

class CounterApp < RubyNative::App
  def initialize
    super
    @count = 0
  end

  def view(page)
    app_name = "Example"
    page.title = app_name
    page.vertical_alignment = RubyNative::MainAxisAlignment::CENTER
    page.horizontal_alignment = RubyNative::CrossAxisAlignment::CENTER

    counter = page.text(value: @count.to_s, size: 48)

    body = page.column(horizontal_alignment: "center", spacing: 8) do
      text "You have pushed the button this many times"
      counter
    end

    page.add(
      body,
      appbar: page.app_bar(
        bgcolor: "#2196F3",
        color: "#FFFFFF",
        title: page.text(value: app_name)
      ),
      floating_action_button: page.fab("+", on_click: ->(e) {
        @count += 1
        e.page.update(counter, value: @count.to_s)
      })
    )
  end
end

CounterApp.new.run
