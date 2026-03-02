# frozen_string_literal: true

module RufletStudio
  module Views
    def detail_view(page, title, content, source_path: nil)
      route = page.route
      page.view(
        route: route,
        bgcolor: color_bg(page),
        scroll: "auto",
        appbar: page.app_bar(
          bgcolor: color_surface(page),
          color: color_text(page),
          title: page.text(value: title, size: 18),
          leading: page.icon_button(
            icon: "arrow_back",
            on_click: ->(_e) { page.go("/gallery") }
          ),
          actions: begin
            action = github_action(page, source_path)
            action ? [action] : []
          end
        ),
        navigation_bar: nav_bar(page, "/gallery"),
        padding: 16,
        controls: [
          content
        ]
      )
    end
  end
end
