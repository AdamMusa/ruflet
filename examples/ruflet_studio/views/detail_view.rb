# frozen_string_literal: true

module RufletStudio
  module Views
    def detail_view(page, title, content)
      route = page.route
      page.view(
        route: route,
        bgcolor: "#111318",
        appbar: page.app_bar(
          bgcolor: "#111318",
          color: "#e7e9ec",
          title: page.text(value: title, size: 18),
          leading: page.icon_button(
            icon: "arrow_back",
            on_click: ->(_e) { page.go("/gallery") }
          )
        ),
        navigation_bar: nav_bar(page, "/gallery"),
        padding: 16,
        controls: [
          page.column(
            spacing: 12,
            scroll: "auto",
            controls: [
              content
            ]
          )
        ]
      )
    end
  end
end
