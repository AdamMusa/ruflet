# frozen_string_literal: true

module Showcase
  module SectionsMedia
    def build_connectivity(page, status)
      current_text = text(value: "")
      page.connectivity(
        on_change: lambda { |event|
          values = Array(event&.data).map(&:to_s)
          label = values.empty? ? "none" : values.join(", ")
          page.update(current_text, value: label)
        }
      )

      column(
        spacing: 12,
        children: [
          status,
          row(
            children: [
              button(
                content: "Get connectivity",
                icon: 'wifi',
                on_click: ->(_e) do
                  page.get_connectivity(
                    on_result: lambda { |result, error|
                      if error && !error.to_s.empty?
                        page.update(current_text, value: "Connectivity error: #{error}")
                        next
                      end

                      values = Array(result).map(&:to_s)
                      label = values.empty? ? "none" : values.join(", ")
                      page.update(current_text, value: label)
                    }
                  )
                end
              ),
              container(expand: true, content: current_text)
            ]
          )
        ]
      )
    end
  end
end
