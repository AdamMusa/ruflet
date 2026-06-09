# frozen_string_literal: true

module Showcase
  module Views
    def detail_view(page, title, content, source_path: nil, scroll: "auto", horizontal_alignment: "center", padding: 16, back_route: "/gallery")
      route = page.route
      control(:view,
        route: route,
        bgcolor: color_bg(page),
        scroll: nil,
        horizontal_alignment: horizontal_alignment,
        padding: 0,
        appbar: app_bar(
          bgcolor: color_surface(page),
          color: color_text(page),
          title: text(value: title, style: { size: 18 }),
          leading: icon_button(
            icon: Ruflet::MaterialIcons::ARROW_BACK,
            on_click: ->(_e) { page.go(back_route) }
          ),
          actions: begin
            action = github_action(page, source_path)
            action ? [action] : []
          end
        ),
        children: [
          column(
            expand: true,
            spacing: 0,
            children: [
              container(
                expand: true,
                alignment: "center",
                padding: padding,
                content: column(
                  expand: true,
                  scroll: scroll,
                  horizontal_alignment: horizontal_alignment,
                  children: [content]
                )
              ),
              nav_bar(page, "/gallery")
            ]
          )
        ]
      )
    end
  end
end
