$LOAD_PATH.unshift(File.expand_path("../packages/ruby_native/lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../packages/ruby_native_ui/lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../packages/ruby_native_server/lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../packages/ruby_native_protocol/lib", __dir__))
require "ruby_native"

class MainApp < RubyNative::App
  def view(page)
    app_name = "RubyNative Tabs Demo"
    page.title = app_name

    tabs = page.tabs(
      height: 320,
      selected_index: 0,
      tabs: [
        page.tab(
          label: page.text(value: "Home"),
          content: page.container(padding: 16, content: page.text(value: "Home tab", size: 24))
        ),
        page.tab(
          label: page.text(value: "Play"),
          content: page.container(padding: 16, content: page.text(value: "Play tab", size: 24))
        ),
        page.tab(
          label: page.text(value: "About"),
          content: page.container(padding: 16, content: page.text(value: "About tab", size: 24))
        )
      ]
    )

    bottom_tabs = page.navigation_bar(
      selected_index: 0,
      on_change: ->(e) { page.title = "#{app_name} (tab #{e.data})" },
      destinations: [
        page.navigation_bar_destination(icon: page.icon(icon: RubyNative::MaterialIcons::HOME), label: "Home"),
        page.navigation_bar_destination(icon: page.icon(icon: RubyNative::MaterialIcons::SPORTS_ESPORTS), label: "Play"),
        page.navigation_bar_destination(icon: page.icon(icon: RubyNative::MaterialIcons::SETTINGS), label: "Settings")
      ]
    )

    page.add(
      tabs,
      appbar: page.app_bar(
        bgcolor: "#d9d7db",
        color: "#232329",
        title: page.text(value: app_name, size: 18)
      ),
      floating_action_button: page.fab(
        page.icon(icon: RubyNative::MaterialIcons::ADD),
        bgcolor: "#232329",
        color: "#ffffff",
        on_click: ->(_e) {}
      ),
      navigation_bar: bottom_tabs
    )
  end
end

MainApp.new.run
