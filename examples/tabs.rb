require "ruflet"

class TabsDemoApp < Ruflet::App
  def view(page)
    app_name = "Ruflet Tabs Demo"
    page.title = app_name

    tabs_control = tabs(
      height: 320,
      selected_index: 0,
      children: [
        tab(
          label: text("Home"),
          children: [container(padding: 16, content: text(value: "Home tab", style: { size: 24 }))]
        ),
        tab(
          label: text("Play"),
          children: [container(padding: 16, content: text(value: "Play tab", style: { size: 24 }))]
        ),
        tab(
          label: text("About"),
          children: [container(padding: 16, content: text(value: "About tab", style: { size: 24 }))]
        )
      ]
    )

    bottom_tabs = navigation_bar(
      selected_index: 0,
      on_change: ->(e) { page.title = "#{app_name} (tab #{e.data})" },
      destinations: [
        navigation_bar_destination(icon: Ruflet::MaterialIcons::HOME, label: "Home"),
        navigation_bar_destination(icon: Ruflet::MaterialIcons::SPORTS_ESPORTS, label: "Play"),
        navigation_bar_destination(icon: Ruflet::MaterialIcons::SETTINGS, label: "Settings")
      ]
    )

    page.add(
      tabs_control,
      appbar: app_bar(
        bgcolor: "#d9d7db",
        color: "#232329",
        title: text(value: app_name, style: { size: 18 })
      ),
      floating_action_button: fab(
        icon: Ruflet::MaterialIcons::ADD,
        bgcolor: "#232329",
        foreground_color: "#ffffff",
        on_click: ->(_e) {}
      ),
      navigation_bar: bottom_tabs
    )
  end
end

TabsDemoApp.new.run
