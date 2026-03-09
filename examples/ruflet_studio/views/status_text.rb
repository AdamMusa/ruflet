# frozen_string_literal: true

module RufletStudio
  module Views
    def status_text(page)
      text(value: "Ready", style: { size: 12, color: color_subtle(page) })
    end
  end
end
