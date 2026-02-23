require "ruby_native"

class CounterApp < RubyNative::App
  def initialize
    super
    @count = 0
  end

  def view(page)
    app_name = "Example"
    page.title = app_name
    page.vertical_alignment = "center"
    page.horizontal_alignment = "center"

    counter = page.text(value: @count.to_s, size: 48)

    page.add(
      appbar: page.app_bar(
        bgcolor: "#2196F3",
        color: "#FFFFFF",
        title: page.text(value: app_name)
      ),
      page.column(horizontal_alignment: "center", spacing: 8) do
        text "You have pushed the button this many times"
        counter
      end,
      floating_action_button: page.fab("+", on_click: ->(e) {
        @count += 1
        e.page.update(counter, value: @count.to_s)
      })
    )
  end
end

CounterApp.new.run
