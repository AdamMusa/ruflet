# frozen_string_literal: true

module Showcase
  module SectionsMedia
    def build_semantics_service(page, _status)
      status_text = text(value: "Semantics service registered.")

      page.semantics_service(
        key: "studio_semantics_service",
        data: { "message" => "Showcase semantics service sample" }
      )

      control(
        :safe_area,
        content: column(
          horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
          spacing: 8,
          children: [
            text(value: "Semantics Service"),
            status_text,
            button(
              content: "Refresh data",
              on_click: lambda { |_e|
                page.semantics_service(
                  key: "studio_semantics_service",
                  data: { "message" => "Updated from Showcase" }
                )
                page.update(status_text, value: "Semantics service data refreshed.")
              }
            )
          ]
        )
      )
    end
  end
end
