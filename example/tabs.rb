require "ruflet"

class MainApp < Ruflet::App
  def view(page)
    app_name = "Ruflet Tabs Demo"
    page.title = app_name

    tabs = tabs(
      height: 320,
      selected_index: 0,
      tabs: [
        tab(
          label: text(value: "Home"),
          content: container(padding: 16, content: text(value: "Home tab", size: 24))
        ),
        tab(
          label: text(value: "Play"),
          content: container(padding: 16, content: text(value: "Play tab", size: 24))
        ),
        tab(
          label: text(value: "About"),
          content: container(padding: 16, content: text(value: "About tab", size: 24))
        )
      ]
    )

    bottom_tabs = navigation_bar(
      selected_index: 0,
      on_change: ->(e) { page.title = "#{app_name} (tab #{e.data})" },
      destinations: [
        navigation_bar_destination(icon: icon(icon: Ruflet::MaterialIcons::HOME), label: "Home"),
        navigation_bar_destination(icon: icon(icon: Ruflet::MaterialIcons::SPORTS_ESPORTS), label: "Play"),
        navigation_bar_destination(icon: icon(icon: Ruflet::MaterialIcons::SETTINGS), label: "Settings")
      ]
    )

    page.add(
      tabs,
      appbar: app_bar(
        bgcolor: "#d9d7db",
        color: "#232329",
        title: text(value: app_name, size: 18)
      ),
      floating_action_button: fab(
        icon(icon: Ruflet::MaterialIcons::ADD),
        bgcolor: "#232329",
        color: "#ffffff",
        on_click: ->(_e) {}
      ),
      navigation_bar: bottom_tabs
    )
  end
end

MainApp.new.run
