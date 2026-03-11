# frozen_string_literal: true

module RufletStudio
  module Views
    def detail_view(page, title, content, source_path: nil, scroll: "auto", horizontal_alignment: "center", padding: 16)
      route = page.route
      control(:view,
        route: route,
        bgcolor: color_bg(page),
        scroll: scroll,
        horizontal_alignment: horizontal_alignment,
        appbar: app_bar(
          bgcolor: color_surface(page),
          color: color_text(page),
          title: text(value: title, style: { size: 18 }),
          leading: icon_button(
            icon: "arrow_back",
            on_click: ->(_e) { page.go("/gallery") }
          ),
          actions: begin
            action = github_action(page, source_path)
            action ? [action] : []
          end
        ),
        navigation_bar: nav_bar(page, "/gallery"),
        padding: padding,
        children: [
          content
        ]
      )
    end
  end
end
