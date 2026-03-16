# frozen_string_literal: true

module RufletStudio
  module Views
    def home_view(page)
      route = "/home"
      control(:view,
        route: route,
        bgcolor: color_bg(page),
        padding: 0,
        appbar: app_bar(
          bgcolor: color_surface(page),
          color: color_text(page),
          title: text(value: "Home", style: { size: 20 }),
          actions: []
        ),
        children: [
          column(
            expand: true,
            spacing: 0,
            children: [
              container(
                expand: true,
                padding: 16,
                content: column(
                  spacing: 8,
                  children: [
                    text(value: "Home", style: { size: 18, color: color_text(page) }),
                    text(value: "Use the Gallery tab to explore controls.", style: { color: color_subtle(page) })
                  ]
                )
              ),
              nav_bar(page, route)
            ]
          )
        ]
      )
    end
  end
end
